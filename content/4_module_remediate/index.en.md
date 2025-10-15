---
title: "Module 4: AI-Powered Remediation"
weight: 60
---

In this module, you'll experience the future of infrastructure management: **AI agents that reason over observability data and propose infrastructure fixes**. You'll configure Amazon Q CLI with MCP (Model Context Protocol) servers for Honeycomb and Pulumi, then use Pulumi Neo to automatically generate infrastructure code changes based on the performance issues you discovered in Module 3.

## Module Overview

**Duration:** 30 minutes

**Objectives:**
- Understand MCP (Model Context Protocol) and its role in agentic workflows
- Configure Honeycomb MCP server in Amazon Q
- Configure Pulumi MCP server in Amazon Q
- Use Amazon Q to query observability data from Honeycomb
- Ask AI agent to diagnose the performance bottleneck
- Use Pulumi Neo to generate infrastructure code fix
- Review and apply the fix (human-in-the-loop)
- Verify the fix resolves the performance issue

## What is MCP?

**Model Context Protocol (MCP)** is an open protocol that standardizes how AI assistants connect to data sources and tools. Instead of building custom integrations for each LLM and each service, MCP provides a universal interface.

**MCP enables AI agents to:**
- Query external data sources (Honeycomb traces, Pulumi state)
- Execute actions (deploy infrastructure, run queries)
- Access contextual information in real-time

**In this workshop:**
- **Honeycomb MCP Server**: Lets Amazon Q query your observability data
- **Pulumi MCP Server**: Lets Amazon Q inspect infrastructure and invoke Pulumi Neo
- **Amazon Q CLI**: AI assistant that understands MCP protocol

::alert[**Why This Matters**: With MCP, your AI assistant can go beyond simple chat responses. It can actively reason over live data and propose concrete actions. This is the foundation of **agentic workflows** where AI systems can autonomously (with human oversight) operate infrastructure.]{type="info"}

## Step 1: Verify Amazon Q CLI Installation

Amazon Q CLI should be pre-installed in your VS Code Server environment.

1. Verify installation:
   ```bash
   q --version
   ```

   Expected output: `Amazon Q CLI v0.x.x` or similar

2. If not installed, install it:
   ```bash
   # Installation instructions will be provided by your workshop instructor
   # or follow: https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing.html
   ```

3. Initialize Amazon Q:
   ```bash
   q configure
   ```

   This will:
   - Authenticate with AWS (using your workshop IAM role)
   - Set up default configuration
   - Enable MCP server support

::alert[**Workshop Environment**: In AWS-hosted workshops, Amazon Q is pre-configured with proper IAM permissions. For self-paced learning, ensure your IAM role has AmazonQ access.]{type="warning"}

## Step 2: Set Up Honeycomb MCP Server

The Honeycomb MCP server allows Amazon Q to query your observability data directly.

1. Create MCP configuration directory:
   ```bash
   mkdir -p ~/.config/amazonq/mcp
   ```

2. Create Honeycomb MCP server configuration:
   ```bash
   cat > ~/.config/amazonq/mcp/honeycomb.json << 'EOF'
   {
     "mcpServers": {
       "honeycomb": {
         "command": "npx",
         "args": [
           "-y",
           "@honeycombio/mcp-server-honeycomb"
         ],
         "env": {
           "HONEYCOMB_API_KEY": "YOUR_HONEYCOMB_API_KEY",
           "HONEYCOMB_ENVIRONMENT": "production"
         }
       }
     }
   }
   EOF
   ```

3. Update with your actual Honeycomb API key:
   ```bash
   # Get API key from Pulumi ESC
   HONEYCOMB_KEY=$(pulumi env open honeycomb-pulumi-workshop-dev --json | jq -r '.honeycomb.apiKey')

   # Update configuration
   sed -i "s/YOUR_HONEYCOMB_API_KEY/${HONEYCOMB_KEY}/" ~/.config/amazonq/mcp/honeycomb.json
   ```

4. Test the Honeycomb MCP server:
   ```bash
   q "List available MCP servers"
   ```

   Expected response:
   ```
   Available MCP servers:
   - honeycomb: Query observability data from Honeycomb
   ```

::alert[**Security Note**: MCP server configurations are stored locally and contain API keys. Ensure proper file permissions (`chmod 600 ~/.config/amazonq/mcp/*.json`) and never commit these files to version control.]{type="warning"}

## Step 3: Set Up Pulumi MCP Server

The Pulumi MCP server allows Amazon Q to inspect infrastructure state and invoke Pulumi Neo for code generation.

1. Install Pulumi MCP server globally:
   ```bash
   npm install -g @pulumi/mcp-server-pulumi
   ```

2. Create Pulumi MCP server configuration:
   ```bash
   cat > ~/.config/amazonq/mcp/pulumi.json << 'EOF'
   {
     "mcpServers": {
       "pulumi": {
         "command": "pulumi-mcp-server",
         "args": [],
         "env": {
           "PULUMI_ACCESS_TOKEN": "YOUR_PULUMI_ACCESS_TOKEN",
           "PULUMI_STACK": "dev",
           "PULUMI_PROJECT_PATH": "/workshop/ai-workshop/pulumi"
         }
       }
     }
   }
   EOF
   ```

3. Update with your Pulumi access token:
   ```bash
   # Get current Pulumi token (from your login session)
   PULUMI_TOKEN=$(pulumi whoami --json | jq -r '.token' 2>/dev/null || echo "MANUAL_SETUP_NEEDED")

   if [ "$PULUMI_TOKEN" != "MANUAL_SETUP_NEEDED" ]; then
     sed -i "s/YOUR_PULUMI_ACCESS_TOKEN/${PULUMI_TOKEN}/" ~/.config/amazonq/mcp/pulumi.json
   else
     echo "Please manually update ~/.config/amazonq/mcp/pulumi.json with your Pulumi token"
   fi
   ```

4. Verify both MCP servers are available:
   ```bash
   q "Show me all connected MCP servers and their capabilities"
   ```

   Expected response:
   ```
   Connected MCP servers:

   1. honeycomb
      - Query traces by time range
      - Get trace details by trace ID
      - Run Honeycomb queries (GROUP BY, WHERE, etc.)
      - List datasets

   2. pulumi
      - Inspect stack state
      - Query resource properties
      - Invoke Pulumi Neo for code generation
      - Preview infrastructure changes
   ```

::alert[**MCP Architecture**: Each MCP server runs as a separate process that Amazon Q communicates with via JSON-RPC. This keeps AI assistant logic separate from data source specifics, enabling extensibility.]{type="info"}

## Step 4: Query Honeycomb Data via Amazon Q

Now let's use Amazon Q to query the observability data we collected in Module 3.

1. Ask Amazon Q about recent application performance:
   ```bash
   q "Using the Honeycomb MCP server, show me the P95 latency for chat requests in the last hour for the otel-ai-chatbot dataset"
   ```

   Amazon Q will:
   - Connect to Honeycomb MCP server
   - Construct appropriate Honeycomb query
   - Execute query and return results
   - Format results in a readable way

   Expected output:
   ```
   Querying Honeycomb for P95 latency...

   Results from otel-ai-chatbot dataset (last 1 hour):

   Span: chat.request
   - P50: 320ms
   - P95: 545ms
   - P99: 750ms
   - Count: 247 requests

   Analysis: P95 latency of 545ms is concerning. User experience
   degrades significantly at this latency level.
   ```

2. Ask for more specific analysis:
   ```bash
   q "Using Honeycomb, break down the latency by span name. Which operation is the slowest?"
   ```

   Expected output:
   ```
   Latency breakdown by operation:

   1. genai.chat.completion - P95: 350ms (Bedrock API calls)
   2. db.vector.search - P95: 180ms (OpenSearch queries)
   3. HTTP POST /api/chat - P95: 315ms (Express handler)

   Analysis: Bedrock API calls are the primary bottleneck,
   accounting for ~64% of total request time.
   ```

3. Check for errors:
   ```bash
   q "Query Honeycomb for any errors in the last hour. Group by error message."
   ```

   Expected output:
   ```
   Errors found in last hour:

   - db.vector.search: "Connection timeout" (3 occurrences)
   - genai.chat.completion: "Rate limit exceeded" (1 occurrence)

   Total error rate: 1.6% (4 errors out of 247 requests)
   ```

::alert[**Natural Language Queries**: Notice you don't need to learn Honeycomb's query syntax. Amazon Q translates your natural language request into proper Honeycomb queries using the MCP server.]{type="success"}

## Step 5: Ask Amazon Q to Diagnose the Issue

Now let's have Amazon Q analyze the infrastructure and propose a solution.

1. Provide context and ask for diagnosis:
   ```bash
   q "I'm seeing P95 latency of 545ms for my otel-ai-chatbot application. \
   The Bedrock API calls take 350ms P95 and OpenSearch queries take 180ms P95. \
   Using the Pulumi MCP server, inspect the current ECS task configuration \
   and tell me if resource constraints could be contributing to the latency."
   ```

   Amazon Q will:
   - Connect to Pulumi MCP server
   - Inspect the current stack state
   - Examine ECS task definition (CPU, memory)
   - Analyze CloudWatch metrics (if available)
   - Correlate with observed latency patterns

   Expected response:
   ```
   Analyzing infrastructure...

   Current ECS Task Configuration:
   - CPU: 512 units (0.5 vCPU)
   - Memory: 1024 MB (1 GB)
   - Task count: 1

   CloudWatch Metrics (last hour):
   - CPU Utilization: Average 68%, Max 89%
   - Memory Utilization: Average 76%, Max 82%

   Diagnosis:
   Your ECS task is CPU-constrained. With only 0.5 vCPU, the task
   frequently hits 85-90% CPU utilization under load. This causes:

   1. CPU contention for all operations
   2. Increased context switching overhead
   3. Degraded performance for CPU-bound tasks (JSON parsing, etc.)
   4. Slower network I/O due to CPU starvation

   The Bedrock API calls themselves may be fine, but the CPU constraint
   adds overhead to request processing, making everything slower.

   Recommendation: Increase ECS task CPU to 1024 units (1 vCPU).

   Expected Impact:
   - P95 latency reduction: 545ms → ~380ms (-30%)
   - CPU utilization: 89% → ~55%
   - Better headroom for traffic spikes
   ```

::alert[**This is the key insight**: The AI agent correlated observability data (traces) with infrastructure configuration (ECS task size) to diagnose that the performance issue is infrastructure-related, not application-related.]{type="success"}

## Step 6: Invoke Pulumi Neo for Code Generation

Now let's use **Pulumi Neo**, Pulumi's AI agent, to generate the infrastructure code change.

1. Ask Amazon Q to generate the fix using Pulumi Neo:
   ```bash
   q "Using the Pulumi MCP server, invoke Pulumi Neo to generate a patch \
   that increases the ECS task CPU from 512 to 1024 units. \
   Show me the diff before I apply it."
   ```

   Amazon Q will:
   - Connect to Pulumi MCP server
   - Invoke Pulumi Neo with the task: "increase ECS task CPU to 1024"
   - Neo analyzes the current infrastructure code
   - Neo generates a code patch
   - Returns the diff for human review

   Expected response:
   ```
   Invoking Pulumi Neo...

   Neo has generated the following patch for pulumi/index.ts:

   --- a/pulumi/index.ts
   +++ b/pulumi/index.ts
   @@ -285,7 +285,7 @@
        taskDefinition: {
          family: `${appName}-task-${environment}`,
          networkMode: "awsvpc",
   -      cpu: "512",  // 0.5 vCPU
   +      cpu: "1024", // 1 vCPU
          memory: "1024", // 1 GB
          requiresCompatibilities: ["FARGATE"],
          executionRoleArn: executionRole.arn,

   Changes summary:
   - Line 288: cpu: "512" → cpu: "1024"

   Impact analysis:
   - Resources modified: 1 (ECS Task Definition)
   - Resources replaced: ECS Service will perform rolling update
   - Estimated deployment time: 3-5 minutes
   - Cost impact: ~$10/month additional (~$15/month → $25/month)

   This change is safe to apply. ECS will perform a rolling update,
   maintaining availability during deployment.
   ```

2. Review the generated patch carefully:
   - Is the change correct? ✓ (CPU increased from 512 to 1024)
   - Is the change safe? ✓ (Rolling update, no downtime)
   - Are there any unintended side effects? ✗ (None identified)

::alert[**Human-in-the-Loop**: This is a critical moment! The AI agent has proposed a change, but YOU (the human) must review and approve it. Never blindly apply AI-generated infrastructure changes without understanding their impact.]{type="warning"}

## Step 7: Apply the Fix

After reviewing the patch, apply it:

1. Apply the patch to your infrastructure code:
   ```bash
   cd /workshop/ai-workshop/pulumi
   q "Apply the Pulumi Neo patch to increase ECS task CPU"
   ```

   Amazon Q will:
   - Write the patch to `pulumi/index.ts`
   - Create a backup of the original file
   - Confirm the change was applied

2. Preview the infrastructure change with Pulumi:
   ```bash
   pulumi env run honeycomb-pulumi-workshop-dev -i -- pulumi preview
   ```

   Expected output:
   ```
   Previewing update (dev)

   ~  aws:ecs:TaskDefinition otel-ai-chatbot-task-dev updating
      [urn=...]
      [diff: ~cpu: "512" => "1024"]

   ~  aws:ecs:Service otel-ai-chatbot-service-dev updating
      [urn=...]
      [diff: ~taskDefinition]

   Resources:
       ~ 2 to update
       28 unchanged

   Do you want to perform this update?
   ```

3. Apply the change:
   ```bash
   pulumi env run honeycomb-pulumi-workshop-dev -i -- pulumi up --yes
   ```

   This will:
   - Update ECS task definition with new CPU allocation (~30 seconds)
   - Trigger ECS service rolling update (~3-5 minutes)
   - Gradually replace old tasks with new tasks
   - Maintain availability throughout

4. Monitor the deployment:
   ```bash
   pulumi env run honeycomb-pulumi-workshop-dev -i -- aws ecs describe-services \
     --cluster $(pulumi stack output ecsClusterName) \
     --services $(pulumi stack output ecsServiceName) \
     --query 'services[0].events[0:5]'
   ```

   Watch for events like:
   ```
   (service otel-ai-chatbot-service-dev) has started 1 tasks
   (service otel-ai-chatbot-service-dev) has stopped 1 running tasks
   (service otel-ai-chatbot-service-dev) has reached a steady state
   ```

::alert[**Zero Downtime Deployment**: ECS Fargate performs rolling updates automatically. The old task continues serving traffic until the new task passes health checks, ensuring zero downtime.]{type="info"}

## Step 8: Verify the Fix

Now let's verify that the fix improved performance:

1. Generate load again:
   ```bash
   cd /workshop/ai-workshop
   ./scripts/generate-load.sh &
   LOAD_PID=$!
   ```

2. Let it run for 3-5 minutes to collect new telemetry data.

3. Query Honeycomb for updated latency:
   ```bash
   q "Using Honeycomb, compare P95 latency for chat requests before and after the deployment. \
   Use the deployment time as the comparison point."
   ```

   Expected output:
   ```
   Latency comparison (before vs. after CPU increase):

   BEFORE (last 2 hours, before deployment):
   - P50: 320ms
   - P95: 545ms
   - P99: 750ms

   AFTER (last 30 minutes, after deployment):
   - P50: 240ms (-25%)
   - P95: 380ms (-30%)
   - P99: 520ms (-31%)

   Improvement: P95 latency reduced by 165ms (30% improvement)

   Analysis: The CPU increase successfully reduced latency across
   all percentiles. The system now has more headroom for traffic spikes.
   ```

4. Check CPU utilization post-fix:
   ```bash
   pulumi env run honeycomb-pulumi-workshop-dev -i -- aws cloudwatch get-metric-statistics \
     --namespace AWS/ECS \
     --metric-name CPUUtilization \
     --dimensions Name=ServiceName,Value=$(pulumi stack output ecsServiceName | tr -d '"') \
                 Name=ClusterName,Value=$(pulumi stack output ecsClusterName | tr -d '"') \
     --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average
   ```

   Expected result:
   - CPU utilization: ~50-55% average (down from 68% average, 89% peak)
   - Much more headroom for traffic spikes

5. Stop load generator:
   ```bash
   kill $LOAD_PID
   ```

::alert[**Success!** You've successfully used AI agents to diagnose an infrastructure issue, generate a code fix, and apply it with human oversight. The application performance improved by 30% without any application code changes.]{type="success"}

## Step 9: Create a Pull Request (Optional)

In a real workflow, you'd commit this change and create a PR:

```bash
cd /workshop/ai-workshop/pulumi
git checkout -b fix/increase-ecs-cpu
git add index.ts
git commit -m "Increase ECS task CPU to 1024 units

Based on observability analysis in Honeycomb, the application
was CPU-constrained with 512 CPU units (0.5 vCPU). Under load,
CPU utilization hit 85-90%, causing P95 latency of 545ms.

Increasing to 1024 CPU units (1 vCPU) reduces P95 latency to
380ms (-30% improvement) and provides headroom for traffic spikes.

Generated by: Pulumi Neo
Reviewed by: [Your Name]
"

git push origin fix/increase-ecs-cpu
```

Then create a PR on GitHub with:
- **Title**: `Fix: Increase ECS task CPU to improve latency`
- **Description**: Include Honeycomb screenshots showing before/after latency
- **Reviewers**: Tag your team for approval

::alert[**Enterprise Workflow**: In production environments, all infrastructure changes should go through code review and CI/CD pipelines, even if AI-generated. The human-in-the-loop step ensures safety and knowledge sharing.]{type="info"}

## Step 10: Explore Further Optimizations

Now ask Amazon Q for additional recommendations:

```bash
q "Based on the observability data in Honeycomb and the current infrastructure in Pulumi, \
what other optimizations could improve performance or reduce costs?"
```

Amazon Q might suggest:
- **Implement caching**: Cache OpenSearch results for common queries
- **Optimize OpenSearch**: Increase shard count or instance size
- **Add autoscaling**: Scale ECS tasks based on CPU utilization
- **Implement rate limiting**: Protect against traffic spikes
- **Add CDN**: Cache static frontend assets on CloudFront
- **Optimize embeddings**: Reduce vector dimensions (1536 → 768)

You can then ask Amazon Q to help implement any of these optimizations using the same workflow!

## Module Summary

Congratulations! You've successfully:

✅ Configured MCP servers for Honeycomb and Pulumi
✅ Connected Amazon Q CLI to your observability and infrastructure data
✅ Used natural language to query Honeycomb traces
✅ Asked AI agent to diagnose performance bottleneck
✅ Invoked Pulumi Neo to generate infrastructure code fix
✅ Reviewed the AI-generated patch (human-in-the-loop)
✅ Applied the fix using Pulumi
✅ Verified performance improvement in Honeycomb
✅ Understood the end-to-end agentic workflow

## What's Next?

In the **Cleanup** section, you'll tear down all the resources you've deployed to avoid ongoing costs.

---

## Key Takeaways

### The Agentic Workflow

This module demonstrated a complete **agentic workflow** where AI systems:
1. **Observe**: Query observability data autonomously
2. **Reason**: Correlate metrics with infrastructure state
3. **Propose**: Generate concrete remediation actions
4. **Execute**: Apply changes with human oversight

This is fundamentally different from traditional "chatbot" workflows. The AI isn't just answering questions—it's actively operating on your systems.

### Human-in-the-Loop is Critical

While AI agents can propose changes, **humans must review and approve** them. This ensures:
- **Safety**: Prevents unintended infrastructure changes
- **Learning**: Teams understand why changes are being made
- **Compliance**: Maintains audit trails and accountability
- **Context**: AI may miss business-specific constraints

### MCP Enables Extensibility

The Model Context Protocol makes this workflow possible by:
- **Standardizing**: Common interface for all data sources
- **Decoupling**: AI logic separate from data source specifics
- **Extending**: Easy to add new MCP servers (GitHub, Slack, PagerDuty, etc.)

Imagine adding:
- **GitHub MCP server**: AI can create PRs automatically
- **Slack MCP server**: AI can notify team of changes
- **PagerDuty MCP server**: AI can acknowledge and remediate incidents

### This is Just the Beginning

We've only scratched the surface. Future capabilities might include:
- **Fully automated remediation**: AI applies fixes during off-hours with post-hoc human review
- **Predictive optimization**: AI anticipates issues before they occur
- **Multi-system reasoning**: AI coordinates changes across multiple services
- **Cost optimization**: AI continuously right-sizes resources based on usage patterns

---

## Troubleshooting

### MCP Server Not Connecting

**Symptom**: Amazon Q says "Honeycomb MCP server unavailable"

**Solution**:
1. Check MCP configuration file exists:
   ```bash
   cat ~/.config/amazonq/mcp/honeycomb.json
   ```

2. Verify API key is set correctly:
   ```bash
   jq .mcpServers.honeycomb.env.HONEYCOMB_API_KEY ~/.config/amazonq/mcp/honeycomb.json
   ```

3. Test MCP server manually:
   ```bash
   npx -y @honeycombio/mcp-server-honeycomb
   ```

### Pulumi Neo Not Available

**Symptom**: Amazon Q says "Pulumi Neo is not enabled for this stack"

**Solution**:
1. Verify you're on Pulumi Cloud (not self-hosted Pulumi backend)
2. Check your Pulumi organization has Neo enabled (may require paid plan)
3. Contact Pulumi support to enable Neo access

### Amazon Q Returns Incorrect Analysis

**Symptom**: AI agent makes wrong conclusions from data

**Solution**:
- **Provide more context**: Be explicit about what you're observing
- **Ask follow-up questions**: "Why did you conclude X?"
- **Verify data sources**: Check that MCP servers are returning correct data
- **Use specific time ranges**: "last hour" vs "last 24 hours" can dramatically change results

---

## Additional Resources

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Honeycomb MCP Server Documentation](https://github.com/honeycombio/mcp-server-honeycomb)
- [Pulumi MCP Server Documentation](https://github.com/pulumi/mcp-server-pulumi)
- [Pulumi Neo Documentation](https://www.pulumi.com/docs/pulumi-cloud/copilot/neo/)
- [Amazon Q Developer CLI Documentation](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line.html)
- [Building Agentic Workflows (Andrew Ng)](https://www.deeplearning.ai/the-batch/how-agents-can-improve-llm-performance/)
