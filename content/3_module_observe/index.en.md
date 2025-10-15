---
title: "Module 3: Observe and Analyze"
weight: 50
---

In this module, you'll use Honeycomb to analyze the telemetry data from your instrumented application. You'll learn how to query observability data, identify performance bottlenecks, and discover resource constraints that need remediation.

## Module Overview

**Duration:** 20 minutes

**Objectives:**
- Generate realistic load on the application
- Explore traces in Honeycomb's interface
- Use Honeycomb's query builder to analyze patterns
- Identify performance bottlenecks (OpenSearch queries, Bedrock calls)
- Discover resource constraints (undersized ECS tasks)
- Create custom visualizations and boards

## Step 1: Generate Application Load

To observe meaningful patterns, let's generate realistic traffic:

1. Create a load generation script:

```bash
cd /workshop/ai-workshop
cat > scripts/generate-load.sh << 'EOF'
#!/bin/bash

ALB_URL=${1:-$(cd pulumi && pulumi stack output albUrl)}

echo "Generating load on: $ALB_URL"
echo "Press Ctrl+C to stop"

QUESTIONS=(
  "How do I instrument Express.js with OpenTelemetry?"
  "What are semantic conventions?"
  "How do I create custom spans?"
  "How can I instrument a React web application?"
  "What is distributed tracing?"
  "How do I configure OpenTelemetry exporters?"
  "What's the difference between manual and automatic instrumentation?"
  "How do I add custom attributes to spans?"
)

while true; do
  # Random question
  QUESTION=${QUESTIONS[$RANDOM % ${#QUESTIONS[@]}]}

  echo "Sending: $QUESTION"

  curl -X POST "${ALB_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"$QUESTION\"}" \
    -w "\nHTTP Status: %{http_code}, Time: %{time_total}s\n" \
    -s -o /dev/null

  # Random delay between 1-3 seconds
  sleep $((1 + RANDOM % 3))
done
EOF

chmod +x scripts/generate-load.sh
```

2. Run the load generator in the background:

```bash
./scripts/generate-load.sh &
LOAD_PID=$!
echo "Load generator PID: $LOAD_PID"
```

3. Let it run for 2-3 minutes to generate sufficient data. You can monitor CloudWatch logs:

```bash
pulumi env run honeycomb-pulumi-workshop-dev -i -- aws logs tail \
  /aws/ecs/otel-ai-chatbot-logs \
  --follow --filter-pattern "POST /api/chat"
```

Press `Ctrl+C` after observing requests flowing through.

::alert[**Load Generation**: We're generating realistic chat requests with varying questions to simulate real user behavior. This helps us observe latency patterns and identify bottlenecks.]{type="info"}

## Step 2: Explore Traces in Honeycomb

1. Open Honeycomb: https://ui.honeycomb.io

2. Select your dataset: `otel-ai-chatbot`

3. You should see a stream of traces in the **Recent Traces** view

4. Click on any trace to see its details:
   - Trace timeline showing all spans
   - Waterfall view of span hierarchy
   - Span attributes and metadata
   - Duration breakdown by span

5. Examine a typical trace structure:
   ```
   chat.request (350ms)
   ├─ POST /api/chat (345ms)
   │  ├─ db.vector.search (120ms)
   │  │  └─ HTTPS POST OpenSearch (115ms)
   │  ├─ genai.chat.completion (210ms)
   │  │  └─ AWS Bedrock InvokeModel (205ms)
   │  └─ Response serialization (5ms)
   ```

**Key observations:**
- Most time is spent in Bedrock API calls (~60% of request time)
- OpenSearch vector search is the second slowest operation (~35%)
- Application logic overhead is minimal (~5%)

## Step 3: Query Data with Honeycomb

Honeycomb's power comes from its ability to slice and dice high-cardinality data. Let's explore some queries:

### Query 1: Average Latency by Operation

1. In Honeycomb, click **New Query**

2. Set up the query:
   - **VISUALIZE**: `P50(duration_ms)`, `P95(duration_ms)`, `P99(duration_ms)`
   - **GROUP BY**: `name` (span name)
   - **Time Range**: Last 1 hour

3. Click **Run Query**

**Expected Results:**
```
Span Name                    P50    P95    P99
-------------------------------------------------
genai.chat.completion       200ms  350ms  500ms
db.vector.search            100ms  180ms  250ms
chat.request                320ms  550ms  750ms
POST /api/chat              315ms  545ms  745ms
```

**Insights:**
- Bedrock calls have highest latency
- Vector search is moderately slow
- Some P99 latencies exceed 500ms (poor user experience)

### Query 2: Token Usage Analysis

1. Create a new query:
   - **VISUALIZE**: `SUM(gen_ai.usage.input_tokens)`, `SUM(gen_ai.usage.output_tokens)`
   - **WHERE**: `gen_ai.request.model` exists
   - **GROUP BY**: `time` (heatmap or line chart)
   - **Time Range**: Last 1 hour

2. **Run Query**

**Expected Results:**
- Input tokens: ~500-800 per request (RAG context + user question)
- Output tokens: ~200-400 per response
- Total: ~700-1200 tokens per request

::alert[**Cost Analysis**: With Claude 3.5 Sonnet pricing (~$3 per million input tokens, ~$15 per million output tokens), each request costs approximately $0.003-0.005. At 1000 requests/day, that's $3-5/day just for LLM calls.]{type="warning"}

### Query 3: Error Rate Analysis

1. Create a new query:
   - **VISUALIZE**: `COUNT`
   - **WHERE**: `error` = `true`
   - **GROUP BY**: `name`, `error.message`
   - **Time Range**: Last 1 hour

2. **Run Query**

**Expected Results** (if errors exist):
```
Span Name                Error Message                    Count
---------------------------------------------------------------
db.vector.search        Connection timeout                  3
genai.chat.completion   Rate limit exceeded                 1
```

**Insights:**
- Occasional OpenSearch timeouts (resource constraint?)
- Rare Bedrock rate limiting

### Query 4: Slowest Traces

1. Create a new query:
   - **VISUALIZE**: `HEATMAP(duration_ms)`
   - **WHERE**: `name` = `chat.request`
   - **Time Range**: Last 1 hour

2. Click on the slowest bucket in the heatmap

3. Honeycomb will show you example traces from that bucket

4. Click on the slowest trace to investigate

**Common causes of slow traces:**
- Cold start (OpenSearch first query)
- Large context size (more tokens → longer Bedrock processing)
- Network latency spikes

## Step 4: Identify the Bottleneck

Let's create a query specifically to identify our bottleneck:

### Query: Breakdown by Service Component

1. Create a new query:
   - **VISUALIZE**: `P95(duration_ms)`
   - **WHERE**: `service.name` = `otel-ai-chatbot`
   - **GROUP BY**: `name`
   - **ORDER BY**: `P95(duration_ms)` DESC
   - **LIMIT**: 10

2. **Run Query**

**Results**:
```
Operation                   P95 Duration
-----------------------------------------
genai.chat.completion       350ms  ← SLOWEST
db.vector.search           180ms  ← SECOND SLOWEST
chat.request               545ms  (aggregate)
```

**Conclusion**: The LLM calls to Bedrock are our primary bottleneck.

## Step 5: Correlate with Infrastructure Metrics

Now let's see if this is an infrastructure issue (undersized resources) or an application issue.

1. Navigate to **CloudWatch Metrics** in AWS Console

2. Check ECS metrics for your service:
   - **CPUUtilization**: Check if consistently >80%
   - **MemoryUtilization**: Check if consistently >80%

3. Run this command to get current utilization:

```bash
pulumi env run honeycomb-pulumi-workshop-dev -i -- aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$(pulumi stack output ecsServiceName | tr -d '"') \
              Name=ClusterName,Value=$(pulumi stack output ecsClusterName | tr -d '"') \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Expected observation:**
- CPU utilization: 60-70% average, spikes to 85-90%
- Memory utilization: 75-80% consistent

**Analysis**: The ECS task is undersized (0.5 vCPU, 1GB RAM). Under load, it's CPU-constrained, which makes Bedrock calls appear even slower due to CPU contention.

## Step 6: Create a Honeycomb Board

Boards in Honeycomb let you create dashboards for ongoing monitoring. Let's create one:

1. In Honeycomb, click **Boards** → **New Board**

2. Name it: "OTel AI Chatbot Performance"

3. Add the following queries as separate graphs:

**Graph 1: Request Latency**
- **VISUALIZE**: `P50(duration_ms)`, `P95(duration_ms)`, `P99(duration_ms)`
- **WHERE**: `name` = `chat.request`
- **Graph Type**: Line chart

**Graph 2: Request Rate**
- **VISUALIZE**: `COUNT`
- **WHERE**: `name` = `chat.request`
- **GROUP BY**: `time` (1-minute buckets)
- **Graph Type**: Line chart

**Graph 3: Error Rate**
- **VISUALIZE**: `COUNT`
- **WHERE**: `error` = `true`
- **GROUP BY**: `error.message`
- **Graph Type**: Bar chart

**Graph 4: Bedrock Token Usage**
- **VISUALIZE**: `SUM(gen_ai.usage.input_tokens)`, `SUM(gen_ai.usage.output_tokens)`
- **WHERE**: `gen_ai.request.model` exists
- **GROUP BY**: `time` (5-minute buckets)
- **Graph Type**: Stacked area chart

**Graph 5: OpenSearch Query Performance**
- **VISUALIZE**: `P95(duration_ms)`
- **WHERE**: `name` = `db.vector.search`
- **GROUP BY**: `db.vector.k` (number of results requested)
- **Graph Type**: Line chart

4. Click **Save Board**

::alert[**Dashboards vs. Exploratory Analysis**: Boards are great for monitoring known metrics. But Honeycomb's real power is ad-hoc queries when investigating incidents or exploring new patterns.]{type="info"}

## Step 7: Set Up an Alert (Optional)

Let's create a simple alert for high latency:

1. In Honeycomb, go to **Triggers** → **New Trigger**

2. Configure:
   - **Name**: High P95 Latency
   - **Query**:
     - VISUALIZE: `P95(duration_ms)`
     - WHERE: `name` = `chat.request`
   - **Threshold**: Alert when P95 > 500ms
   - **Evaluation Window**: 5 minutes
   - **Notification**: Email or Slack webhook

3. Click **Create Trigger**

Now you'll be notified when latency degrades!

## Step 8: Analyze the Root Cause

Based on our investigation, we've identified:

1. **Primary Bottleneck**: Bedrock API calls (P95: 350ms)
2. **Secondary Bottleneck**: OpenSearch vector search (P95: 180ms)
3. **Infrastructure Constraint**: ECS task is CPU-constrained (0.5 vCPU hitting 85-90% utilization)
4. **Cost Impact**: High token usage (~1000 tokens/request)

**Root Cause Hypothesis:**
- The ECS task has insufficient CPU (0.5 vCPU)
- Under load, CPU contention adds overhead to all operations
- This makes already-slow Bedrock calls appear even slower
- Solution: Increase ECS task CPU allocation

**How would we normally fix this?**
1. Update Pulumi code to change CPU from 512 (0.5 vCPU) to 1024 (1 vCPU)
2. Redeploy with `pulumi up`
3. Monitor to verify improvement

But in Module 4, we'll use **AI agents** to propose and apply this fix automatically!

## Step 9: Stop Load Generator

Before moving to the next module, stop the load generator:

```bash
kill $LOAD_PID
# Or if you lost the PID:
pkill -f generate-load.sh
```

## Module Summary

Congratulations! You've successfully:

✅ Generated realistic load on the application
✅ Explored traces in Honeycomb's interface
✅ Used Honeycomb queries to analyze latency patterns
✅ Identified performance bottlenecks (Bedrock calls, OpenSearch queries)
✅ Discovered infrastructure constraints (undersized ECS tasks)
✅ Created a monitoring board for ongoing visibility
✅ Set up alerting for latency degradation
✅ Formulated a hypothesis for remediation

## What's Next?

In **Module 4**, you'll use **Amazon Q with MCP servers** to:
1. Query Honeycomb data directly from your IDE
2. Ask an AI agent to diagnose the performance issue
3. Use **Pulumi Neo** to generate infrastructure code changes
4. Review and apply the fix (human-in-the-loop)
5. Verify the improvement

---

## Key Takeaways

### High-Cardinality Data is Powerful

Traditional monitoring tools force you to pre-aggregate metrics. Honeycomb stores raw trace data, letting you ask arbitrary questions:
- "Show me traces where Bedrock calls exceeded 500ms AND vector search returned <5 results"
- "Group by user_id to find which users experience the slowest responses"
- "Compare performance before/after code deploy"

### Observability ≠ Monitoring

**Monitoring**: "Is the system up? Are metrics within thresholds?"

**Observability**: "Why is this specific request slow? What's different about it?"

Honeycomb enables **observability-driven development** where you can explore unknown-unknowns.

### The Three Pillars

While we focused on **traces** in this module, remember:
- **Traces**: Request flow and latency breakdown
- **Metrics**: Aggregated numerical data (CPU, memory, request rate)
- **Logs**: Discrete events (errors, debug info)

OpenTelemetry captures all three, and Honeycomb correlates them.

---

## Additional Resources

- [Honeycomb Query Documentation](https://docs.honeycomb.io/working-with-your-data/queries/)
- [Honeycomb Best Practices](https://docs.honeycomb.io/working-with-your-data/best-practices/)
- [OpenTelemetry Trace Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/general/trace/)
- [Charity Majors on Observability](https://www.honeycomb.io/blog/observability-a-manifesto)
