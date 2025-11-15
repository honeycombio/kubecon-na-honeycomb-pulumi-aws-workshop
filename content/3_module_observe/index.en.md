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

Honeycomb's power comes from its ability to slice and dice high-cardinality data. Unlike traditional metrics systems that require pre-aggregation, Honeycomb stores raw events and lets you ask arbitrary questions. This is the difference between **observability** (exploring unknowns) and **monitoring** (tracking known metrics).

::alert[**Honeycomb Philosophy**: Ask "WHY is this happening?" not just "WHAT is happening?" Traditional dashboards show you WHAT (CPU is high), but Honeycomb helps you understand WHY (which users, which endpoints, which code paths).]{type="info"}

### Query 1: Average Latency by Operation

1. In Honeycomb, click **New Query**

2. Set up the query:
   - **VISUALIZE**: `P50(duration_ms)`, `P95(duration_ms)`, `P99(duration_ms)`
   - **GROUP BY**: `name` (span name)
   - **WHERE**: `name` EXISTS (to filter out empty span names)
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

**Best Practice - LIMIT for High Cardinality**: When grouping by high-cardinality fields (like `user.id` or `request.id`), always add a `LIMIT` clause to avoid overwhelming result tables. For example:
- **LIMIT 20**: Show top 20 slowest users
- **ORDER BY**: `P95(duration_ms)` DESC to see worst offenders first

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

### Query 4: Slowest Traces with Heatmap

1. Create a new query:
   - **VISUALIZE**: `HEATMAP(duration_ms)`
   - **WHERE**: `name` = `chat.request`
   - **Time Range**: Last 1 hour

2. Click on the slowest bucket in the heatmap (rightmost columns)

3. Honeycomb will show you example traces from that bucket

4. Click on the slowest trace to investigate

**Common causes of slow traces:**
- Cold start (OpenSearch first query)
- Large context size (more tokens → longer Bedrock processing)
- Network latency spikes
- Resource contention (CPU/memory limits)

::alert[**Heatmaps are Interactive**: Unlike static histograms, Honeycomb's heatmaps let you click on any bucket to see actual traces. This turns data exploration into an interactive investigation.]{type="success"}

### Query 5: Using BubbleUp to Find Outliers

**BubbleUp** is Honeycomb's signature feature that answers: "What's different about these slow requests compared to normal ones?" It automatically analyzes all dimensions and highlights statistically significant differences.

1. From your heatmap query above, click **BubbleUp** in the toolbar

2. Select the **slowest bucket** (P99+ traces) as your target

3. BubbleUp will compare these slow traces against all other traces

4. Look for attributes highlighted in **orange/red** - these have the biggest differences

**Example BubbleUp Results:**

```
Attribute                   Slow Traces    Normal Traces    Impact
-----------------------------------------------------------------------
gen_ai.usage.input_tokens   1200           650             🔴 High
db.vector.k                 15             5               🟠 Medium
http.route                  /api/chat      /api/chat       ⚪ None
deployment.environment      production     production      ⚪ None
```

**Insights from BubbleUp:**
- Slow requests have **2x more input tokens** (1200 vs 650)
- Slow requests fetch **3x more vectors** (15 vs 5)
- This explains the latency: larger context → longer LLM processing

**Why BubbleUp Matters:** Without BubbleUp, you'd manually create dozens of queries grouping by each field. BubbleUp does this automatically in seconds, even with millions of high-cardinality combinations.

::alert[**BubbleUp for Incidents**: During production incidents, BubbleUp is your first tool. It instantly shows you what's different about failing requests: specific users? Certain API versions? Particular code paths? Answer these in 30 seconds instead of 30 minutes.]{type="info"}

### Query 6: Using Query Assistant (Natural Language)

Honeycomb's **Query Assistant** uses AI to translate natural language questions into queries. This is perfect for teams new to Honeycomb or for quickly exploring data without remembering query syntax.

1. Click **Query Assistant** (or the sparkle ✨ icon) in the query builder

2. Try asking questions like:

   **Example 1**: "Show me the slowest Bedrock calls in the last hour"

   Query Assistant translates to:
   - VISUALIZE: `P99(duration_ms)`
   - WHERE: `name` = `genai.chat.completion`
   - ORDER BY: `P99(duration_ms)` DESC
   - Time Range: Last 1 hour

   **Example 2**: "Which users are consuming the most tokens?"

   Query Assistant translates to:
   - VISUALIZE: `SUM(gen_ai.usage.input_tokens)`, `SUM(gen_ai.usage.output_tokens)`
   - GROUP BY: `user.id`
   - ORDER BY: `SUM(gen_ai.usage.total_tokens)` DESC
   - LIMIT: 20

   **Example 3**: "Show me all errors from the last 30 minutes"

   Query Assistant translates to:
   - VISUALIZE: `COUNT`
   - WHERE: `error` = `true` OR `otel.status_code` = `ERROR`
   - GROUP BY: `error.message`, `name`
   - Time Range: Last 30 minutes

3. Review the generated query and click **Run Query**

4. Refine the natural language prompt if needed, or edit the query directly

::alert[**Query Assistant Best Practice**: Use natural language to get started, then refine the query manually. This is great for learning Honeycomb's query language and discovering attributes you didn't know existed.]{type="success"}

### Query 7: HAVING Clause for Advanced Filtering

The **HAVING** clause filters on aggregated results, which is essential when working with high-cardinality data.

**Example: Find users with excessive token usage**

1. Create a query:
   - **VISUALIZE**: `SUM(gen_ai.usage.total_tokens)`, `COUNT`
   - **GROUP BY**: `user.id`
   - **HAVING**: `SUM(gen_ai.usage.total_tokens)` > 10000
   - **ORDER BY**: `SUM(gen_ai.usage.total_tokens)` DESC
   - **LIMIT**: 20

**Why HAVING is powerful:**
- **WHERE** filters raw events before aggregation: "Show requests where duration > 500ms"
- **HAVING** filters aggregated results: "Show users where total tokens > 10000"

**Use cases:**
- Find users with >100 requests/hour (potential abuse)
- Find endpoints with >5% error rate
- Find models with >$10 in API costs per hour

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

## Step 5: Correlate with Infrastructure Metrics in Honeycomb

Now let's correlate application performance with infrastructure resource utilization. Thanks to CloudWatch Metric Streams, ECS metrics are automatically flowing into Honeycomb!

### Query ECS Metrics in the cloudwatch-metrics Dataset

1. **Switch to the `cloudwatch-metrics` dataset** in Honeycomb
   - Click the dataset dropdown in the top-left corner
   - Select `cloudwatch-metrics`
   - This dataset contains all ECS and Container Insights metrics streamed from CloudWatch

2. **Explore available metrics first**:

   In the `cloudwatch-metrics` dataset, click the "Columns" icon to see available fields. CloudWatch metrics come in with suffixes like:
   - `AWS/ECS/CPUUtilization.avg` - Average value
   - `AWS/ECS/CPUUtilization.max` - Maximum value
   - `AWS/ECS/CPUUtilization.min` - Minimum value

3. **Query ECS CPU Utilization**:
   - **VISUALIZE**: `AVG(AWS/ECS/CPUUtilization.avg)`, `MAX(AWS/ECS/CPUUtilization.max)`
   - **WHERE**: `metric_stream_name` EXISTS
   - **GROUP BY**: `time` (5-minute buckets)
   - **Time Range**: Last 1 hour

   **Expected Results**:
   ```
   Time Window    AVG(CPU)    MAX(CPU)
   ----------------------------------------
   10:00-10:05    62%         78%
   10:05-10:10    68%         85%
   10:10-10:15    71%         91%  ← High!
   10:15-10:20    65%         88%
   ```

4. **Query ECS Memory Utilization**:
   - **VISUALIZE**: `AVG(AWS/ECS/MemoryUtilization.avg)`, `MAX(AWS/ECS/MemoryUtilization.max)`
   - **WHERE**: `metric_stream_name` EXISTS
   - **GROUP BY**: `time` (5-minute buckets)
   - **Time Range**: Last 1 hour

   **Expected Results**:
   ```
   Time Window    AVG(Memory)    MAX(Memory)
   ----------------------------------------
   10:00-10:05    76%            79%
   10:05-10:10    78%            82%
   10:10-10:15    77%            81%
   ```

   ::alert[**Metric Naming**: CloudWatch metrics arrive in OpenTelemetry format with the full namespace path (e.g., `AWS/ECS/CPUUtilization`) and aggregation suffixes (`.avg`, `.max`, `.min`). Use `.avg` for typical queries and `.max` to find peak values.]{type="info"}

5. **Correlate with Application Latency**:

   Now switch back to your application dataset (`otel-ai-chatbot-dev` or `otel-ai-chatbot-ws`) and create a parallel query:
   - **VISUALIZE**: `P95(duration_ms)`
   - **WHERE**: `name` = `chat.request`
   - **GROUP BY**: `time` (5-minute buckets)
   - **Time Range**: Last 1 hour (same as infrastructure queries)

   **Compare the patterns**:
   - Notice how P95 latency spikes correlate with CPU utilization spikes
   - When CPU hits 85-90%, latency increases significantly
   - This confirms CPU constraint is affecting application performance

::alert[**Honeycomb Power Move**: Open two browser tabs side-by-side—one with the `cloudwatch-metrics` dataset showing CPU/memory, another with your app dataset showing latency. Use the same time range to visually correlate spikes. In production, you can create a Board with graphs from both datasets for unified monitoring.]{type="success"}

### Using BubbleUp to Find Hot Services

Want to see which specific ECS services or clusters are having resource issues?

1. **In the `cloudwatch-metrics` dataset**, create a query:
   - **VISUALIZE**: `HEATMAP(AWS/ECS/CPUUtilization.max)`
   - **WHERE**: `metric_stream_name` EXISTS
   - **Time Range**: Last 1 hour

2. **Click BubbleUp** on the highest CPU bucket (rightmost columns)

3. **BubbleUp will analyze** and show you:
   - Which CloudWatch dimension values (cluster, service) have the highest CPU
   - Whether specific services are consistently hot
   - If the issue is widespread across the cluster or isolated to certain services

   ::alert[**Pro Tip**: CloudWatch dimensions become fields in Honeycomb. Look for fields like `ClusterName`, `ServiceName`, or `TaskDefinitionFamily` to GROUP BY and narrow down which specific resources are constrained.]{type="success"}

**Analysis**: The ECS task is undersized (0.5 vCPU, 1GB RAM). Under load, CPU consistently hits 85-91%, which causes:
- Increased application latency due to CPU contention
- Bedrock calls appear slower (processes queue for CPU time)
- All operations slow down proportionally

**Root Cause Confirmed**: Infrastructure constraint (undersized ECS task) is the primary bottleneck, not the external services (Bedrock, OpenSearch).

::alert[**Why This Matters**: By querying CloudWatch metrics directly in Honeycomb, you eliminated context switching to the AWS console. You used the same query interface, BubbleUp, and correlation techniques across both infrastructure and application data. This is the power of unified observability.]{type="info"}

## Step 6: Advanced Technique - Derived Columns

**Derived columns** let you create new fields from existing data using mathematical operations or string manipulation. This is powerful for calculating metrics not captured during instrumentation.

**Example: Calculate Cost Per Request**

1. In Honeycomb, go to **Dataset Settings** → **Derived Columns**

2. Create a new derived column:
   - **Name**: `cost_per_request_usd`
   - **Expression**:
     ```
     (gen_ai.usage.input_tokens * 0.000003) +
     (gen_ai.usage.output_tokens * 0.000015)
     ```
   - **Description**: "Estimated cost in USD based on Claude 3.5 Sonnet pricing"

3. Now you can query on this field:
   - **VISUALIZE**: `SUM(cost_per_request_usd)`
   - **GROUP BY**: `user.id`
   - **Time Range**: Last 24 hours

**Other useful derived columns:**
- `tokens_per_second`: `gen_ai.usage.total_tokens / (duration_ms / 1000)` - Throughput metric
- `is_slow_request`: `duration_ms > 500` - Boolean for slow requests
- `error_rate`: `COUNT WHERE error = true / COUNT` - Percentage (use HAVING)

::alert[**Derived Columns Best Practice**: Use derived columns for calculations you'll query repeatedly. They're computed at query time, so there's no storage overhead, but they save you from repeating complex expressions in every query.]{type="success"}

## Step 7: Create a Honeycomb Board

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

**Graph 6: Estimated API Costs** (using derived column)
- **VISUALIZE**: `SUM(cost_per_request_usd)`
- **GROUP BY**: `time` (1-hour buckets)
- **Graph Type**: Line chart

4. Click **Save Board**

::alert[**Dashboards vs. Exploratory Analysis**: Boards are great for monitoring known metrics. But Honeycomb's real power is ad-hoc queries when investigating incidents or exploring new patterns. Always start with exploration, then create boards for recurring questions.]{type="info"}

## Step 8: Migrate from CloudWatch Alarms to Honeycomb Triggers

Traditional AWS deployments use CloudWatch Alarms for alerting. Let's see how to migrate these to Honeycomb Triggers, which work across both application traces and infrastructure metrics.

### Example: ECS CPU Alarm → Honeycomb Trigger

**What the CloudWatch Alarm looked like:**

```typescript
// Traditional CloudWatch Alarm (Pulumi)
const ecsCpuAlarm = new aws.cloudwatch.MetricAlarm("ecs-high-cpu", {
    comparisonOperator: "GreaterThanThreshold",
    evaluationPeriods: 2,
    metricName: "CPUUtilization",
    namespace: "AWS/ECS",
    period: 300,
    statistic: "Average",
    threshold: 80,
    dimensions: {
        ClusterName: cluster.name,
        ServiceName: service.name,
    },
    alarmActions: [snsTopicArn],
});
```

**Honeycomb Trigger equivalent:**

1. In Honeycomb, switch to the `cloudwatch-metrics` dataset

2. Go to **Triggers** → **New Trigger**

3. Configure the trigger:
   - **Name**: ECS High CPU Alert
   - **Query**:
     - **VISUALIZE**: `AVG(AWS/ECS/CPUUtilization.avg)`
     - **WHERE**: `metric_stream_name` EXISTS
     - **GROUP BY**: None (or `ClusterName`, `ServiceName` for per-service alerting)
   - **Threshold**: Alert when `AVG(AWS/ECS/CPUUtilization.avg)` > 80
   - **Evaluation Window**: 5 minutes (equivalent to 2 periods of 300s)
   - **Notification**: Email, Slack, PagerDuty, or webhook

4. Click **Create Trigger**

**Why this is better:**
- ✅ **Unified interface**: Same tool for application AND infrastructure alerts
- ✅ **Rich context**: Click through from alert to query with full BubbleUp capabilities
- ✅ **High-cardinality**: Alert on specific tasks, services, or custom dimensions
- ✅ **Correlation ready**: Immediately correlate with application traces in the same tool

### Example: Application Latency Alert

For application-level alerting:

1. Switch to your application dataset (`otel-ai-chatbot-dev`)

2. Create a new trigger:
   - **Name**: High P95 Latency
   - **Query**:
     - **VISUALIZE**: `P95(duration_ms)`
     - **WHERE**: `name` = `chat.request`
   - **Threshold**: Alert when P95 > 500ms
   - **Evaluation Window**: 5 minutes
   - **Notification**: Email or Slack webhook

3. Click **Create Trigger**

### Module 4 Pattern: Redis Cache Alarms

In Module 4, when AI agents propose adding Redis caching, they also create CloudWatch alarms for:
- Redis CPU utilization
- Redis memory utilization
- Redis eviction rate
- Cache hit rate

These alarms can be migrated to Honeycomb Triggers following the same pattern:
- Query CloudWatch metrics in the `cloudwatch-metrics` dataset
- Set thresholds based on your SLOs
- Benefit from Honeycomb's BubbleUp to identify which specific cache nodes or keys are problematic

::alert[**Infrastructure as Code**: In a production environment, you'd define these triggers in Pulumi using Honeycomb's API. This ensures your alerting is version-controlled alongside your infrastructure. We'll show an example of this in the next step.]{type="info"}

### Step 8a: Creating Honeycomb Triggers as Code (Advanced)

For production environments, you'll want to define triggers as infrastructure-as-code. Here's how to create Honeycomb Triggers using Pulumi's Command provider:

**Example Pulumi code for an ECS CPU trigger:**

```typescript
import * as command from "@pulumi/command";

// Create a Honeycomb Trigger for ECS High CPU
const ecsCpuTrigger = new command.local.Command("honeycomb-ecs-cpu-trigger", {
    create: pulumi.interpolate`curl -X POST https://api.honeycomb.io/1/triggers \
        -H "X-Honeycomb-Team: ${config.requireSecret("honeycombApiKey")}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "ECS High CPU Alert",
            "dataset_slug": "cloudwatch-metrics",
            "query": {
                "calculations": [{
                    "op": "AVG",
                    "column": "AWS/ECS/CPUUtilization.avg"
                }],
                "filters": [{
                    "column": "metric_stream_name",
                    "op": "exists"
                }],
                "time_range": 300
            },
            "threshold": {
                "op": "gt",
                "value": 80
            },
            "alert_type": "on_change",
            "recipients": [{
                "type": "email",
                "target": "ops-team@example.com"
            }]
        }'`,
    update: pulumi.interpolate`echo "Trigger already exists"`,
    delete: pulumi.interpolate`echo "Trigger deletion would go here"`,
});
```

**For Redis cache alarms (Module 4 pattern):**

```typescript
// Redis CPU utilization trigger
const redisCpuTrigger = new command.local.Command("honeycomb-redis-cpu-trigger", {
    create: pulumi.interpolate`curl -X POST https://api.honeycomb.io/1/triggers \
        -H "X-Honeycomb-Team: ${config.requireSecret("honeycombApiKey")}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Redis High CPU",
            "dataset_slug": "cloudwatch-metrics",
            "query": {
                "calculations": [{
                    "op": "AVG",
                    "column": "AWS/ElastiCache/CPUUtilization.avg"
                }],
                "filters": [{
                    "column": "CacheClusterId",
                    "op": "exists"
                }],
                "time_range": 300
            },
            "threshold": {
                "op": "gt",
                "value": 75
            },
            "alert_type": "on_change"
        }'`,
});

// Redis eviction rate trigger
const redisEvictionTrigger = new command.local.Command("honeycomb-redis-eviction-trigger", {
    create: pulumi.interpolate`curl -X POST https://api.honeycomb.io/1/triggers \
        -H "X-Honeycomb-Team: ${config.requireSecret("honeycombApiKey")}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Redis High Evictions",
            "dataset_slug": "cloudwatch-metrics",
            "query": {
                "calculations": [{
                    "op": "SUM",
                    "column": "AWS/ElastiCache/Evictions.sum"
                }],
                "filters": [{
                    "column": "CacheClusterId",
                    "op": "exists"
                }],
                "time_range": 300
            },
            "threshold": {
                "op": "gt",
                "value": 100
            },
            "alert_type": "on_change"
        }'`,
});
```

**Benefits of Triggers as Code:**
- ✅ **Version Control**: All alerting rules tracked in git
- ✅ **Review Process**: Trigger changes go through PR review
- ✅ **Reproducible**: Spin up new environments with identical alerting
- ✅ **Automated**: Deploy triggers alongside infrastructure changes
- ✅ **Auditable**: Full history of who changed what and when

::alert[**Production Tip**: Use a dedicated Honeycomb Configuration API key (not an Ingest key) for creating triggers. Store it in Pulumi ESC or AWS Secrets Manager just like other sensitive configuration.]{type="warning"}

## Step 9: Analyze the Root Cause

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

## Step 10: Stop Load Generator

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

### 1. High-Cardinality Data is Your Superpower

Traditional monitoring tools force you to pre-aggregate metrics, losing the ability to ask detailed questions. Honeycomb stores raw trace data with all high-cardinality attributes intact, letting you ask questions like:
- "Show me traces where Bedrock calls exceeded 500ms AND vector search returned <5 results **AND** user_id = 'user_12345'"
- "Which specific model versions have the highest error rate?"
- "Compare performance before/after deploy for users in region 'us-west-2'"

**The Honeycomb Promise**: You can ask questions you didn't know you needed to ask, without pre-defining dashboards or metrics.

### 2. BubbleUp Accelerates Root Cause Analysis

During incidents, BubbleUp automatically identifies what's different about problematic requests by comparing distributions across all dimensions. This turns hours of manual investigation into 30 seconds of automated analysis. It's particularly powerful with high-cardinality data (millions of users, thousands of model versions).

### 3. Observability ≠ Monitoring

**Monitoring**: "Is the system up? Are metrics within thresholds?" (known-knowns)

**Observability**: "Why is this specific request slow? What's different about it?" (unknown-unknowns)

Honeycomb enables **observability-driven development** where you explore first, then create dashboards for known issues.

### 4. Ask "WHY" Questions, Not Just "WHAT" Questions

Traditional tools answer WHAT: "P99 latency is 750ms"

Honeycomb answers WHY: "P99 latency is 750ms **because** requests from premium users fetch 3x more vector results and use larger context windows"

Use BubbleUp, high-cardinality GROUP BY, and HAVING clauses to answer WHY questions.

### 5. Query Assistant Lowers the Learning Curve

Natural language querying with Query Assistant means teams can start asking questions on day one, without mastering query syntax. It's also excellent for discovering attributes you didn't know existed in your data.

### 6. The Three Pillars, Unified

While we focused on **traces** in this module, remember:
- **Traces**: Request flow and latency breakdown (what we used)
- **Metrics**: Aggregated numerical data (CPU, memory from CloudWatch)
- **Logs**: Discrete events (errors, debug info correlated via trace IDs)

OpenTelemetry captures all three, and Honeycomb correlates them automatically through trace context propagation.

### 7. Heatmaps + HAVING + LIMIT = High-Cardinality Mastery

When working with millions of unique values:
- **Heatmaps**: Visualize distributions and identify outliers interactively
- **HAVING**: Filter on aggregated values (e.g., users with >10K tokens)
- **LIMIT**: Show top N results to avoid overwhelming tables
- **ORDER BY**: Sort by the metric that matters (P95, SUM, etc.)

---

## Additional Resources

- [Honeycomb Query Documentation](https://docs.honeycomb.io/working-with-your-data/queries/)
- [Honeycomb Best Practices](https://docs.honeycomb.io/working-with-your-data/best-practices/)
- [OpenTelemetry Trace Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/general/trace/)
- [Charity Majors on Observability](https://www.honeycomb.io/blog/observability-a-manifesto)
