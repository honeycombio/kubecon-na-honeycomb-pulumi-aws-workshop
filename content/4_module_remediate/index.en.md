---
title: "Module 4: AI-Powered Remediation"
weight: 60
---

In this module, you'll experience the future of infrastructure management: **AI agents that reason over observability data and propose infrastructure fixes**. You'll configure Claude Code (or your preferred AI IDE/CLI) with MCP (Model Context Protocol) servers for Honeycomb and Pulumi, then use Pulumi Neo to automatically generate infrastructure code changes based on the performance issues you discovered in Module 3.

## Module Overview

**Duration:** 30 minutes

**Objectives:**
- Understand MCP (Model Context Protocol) and its role in agentic workflows
- Configure Honeycomb MCP server in Claude Code
- Configure Pulumi MCP server in Claude Code
- Use Claude Code to query observability data from Honeycomb
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
- **Honeycomb MCP Server**: Lets Claude Code query your observability data
- **Pulumi MCP Server**: Lets Claude Code inspect infrastructure and invoke Pulumi Neo
- **Claude Code**: AI assistant that understands MCP protocol (you can also use other AI IDEs like Cursor, Windsurf, or AI CLIs like Zed)

::alert[**Why This Matters**: With MCP, your AI assistant can go beyond simple chat responses. It can actively reason over live data and propose concrete actions. This is the foundation of **agentic workflows** where AI systems can autonomously (with human oversight) operate infrastructure.]{type="info"}

## Step 1: Verify Claude Code Installation

Claude Code should be pre-installed in your VS Code Server environment. If you prefer to use a different AI IDE or CLI (such as Cursor, Windsurf, or Zed), you can follow their respective MCP configuration guides.

1. Verify Claude Code CLI is installed:
   ```bash
   claude --version
   ```

   Expected output: `Claude Code v1.x.x` or similar

2. If not installed, install it by following the instructions at:
   - **Claude Code**: https://claude.ai/download
   - **Alternative**: Visit https://docs.anthropic.com/en/docs/agents-and-tools/mcp to see MCP-compatible tools

3. Verify MCP support is enabled:
   ```bash
   claude mcp list
   ```

   This will show any currently configured MCP servers. Initially, you may see:
   ```
   Checking MCP server health...

   (No servers configured yet)
   ```

   Or if you have other MCP servers configured, they will be listed here.

::alert[**AI Tool Choice**: This workshop uses Claude Code for examples, but the MCP protocol is standardized. You can use any MCP-compatible AI assistant (Cursor, Windsurf, Zed, etc.) with the same MCP servers.]{type="info"}

## Step 2: Add Honeycomb MCP Server

The Honeycomb MCP server allows Claude Code to query your observability data directly. We'll use OAuth authentication, which eliminates the need to manage API keys.

1. Add the Honeycomb MCP server to Claude Code:
   ```bash
   claude mcp add honeycomb --transport http https://mcp.honeycomb.io/mcp
   ```

   This command will:
   - Add the Honeycomb MCP server to your Claude Code configuration
   - Prepare OAuth authentication (authentication happens on first use)

2. Authenticate with Honeycomb (OAuth flow):

   When you first use the Honeycomb MCP server, Claude Code will prompt you to authenticate. The OAuth flow will:
   - Open your browser to Honeycomb's authorization page
   - Ask you to grant Claude Code access to your Honeycomb data
   - Redirect back to Claude Code with authentication complete

   **No API keys needed!** OAuth tokens are managed automatically and securely.

3. Verify the Honeycomb MCP server is configured:
   ```bash
   claude mcp list
   ```

   Expected output:
   ```
   Checking MCP server health...

   honeycomb: https://mcp.honeycomb.io/mcp (HTTP) - ✓ Connected
   ```

4. Test the connection by asking Claude Code:
   ```
   What Honeycomb datasets are available?
   ```

   Claude Code will:
   - Trigger the OAuth flow (if not already authenticated)
   - Query your available datasets
   - Display the results

::alert[**OAuth Benefits**: OAuth authentication is more secure than API keys - tokens are short-lived, automatically refreshed, and can be easily revoked. You never need to copy/paste sensitive credentials!]{type="success"}

::alert[**Documentation**: For detailed Honeycomb MCP configuration options, see: https://docs.honeycomb.io/integrations/mcp/configuration-guide/#setting-up-oauth]{type="info"}

## Step 3: Add Pulumi MCP Server

The Pulumi MCP server allows Claude Code to inspect infrastructure state and invoke Pulumi Neo for code generation.

1. Get your Pulumi organization name:
   ```bash
   pulumi whoami
   ```

   Note the organization name displayed.

2. Add the Pulumi MCP server to Claude Code:
   ```bash
   claude mcp add pulumi --transport http https://mcp.ai.pulumi.com/mcp
   ```

   You'll be prompted to authenticate with Pulumi. The MCP server will use your existing Pulumi access token from your login session.

3. Configure the default organization (optional):

   The Pulumi MCP server will automatically detect your organization from your Pulumi login. If you need to specify a different organization, you can set the `PULUMI_ORG` environment variable when adding the server.

4. Verify both MCP servers are configured:
   ```bash
   claude mcp list
   ```

   Expected output:
   ```
   Checking MCP server health...

   honeycomb: https://mcp.honeycomb.io/mcp (HTTP) - ✓ Connected
   pulumi: https://mcp.ai.pulumi.com/mcp (HTTP) - ✓ Connected
   ```

5. Test by asking Claude Code:
   ```
   What Pulumi stacks do I have in my organization?
   ```

   Claude Code will use the Pulumi MCP server to query your stacks.

::alert[**Documentation**: For detailed Pulumi MCP configuration and capabilities, see: https://www.pulumi.com/docs/iac/using-pulumi/mcp-server/]{type="info"}

::alert[**MCP Architecture**: Each MCP server runs as a hosted service that Claude Code communicates with via HTTP. This keeps AI assistant logic separate from data source specifics, enabling extensibility without local installation.]{type="success"}

## Step 4: Query Honeycomb Data via Claude Code

Now let's use Claude Code to query the observability data we collected in Module 3.

1. Ask Claude Code about recent application performance:
   ```
   Using the Honeycomb MCP server, show me the P95 latency for chat requests in the last hour for the otel-ai-chatbot-backend dataset
   ```

   Claude Code will:
   - Connect to Honeycomb MCP server
   - Construct appropriate Honeycomb query
   - Execute query and return results
   - Format results in a readable way

   Expected output:
   ```
   ┌───────┬──────────────────┬──────────────────┬──────────────────┐
   │ COUNT │ P50(duration_ms) │ P95(duration_ms) │ P99(duration_ms) │
   ├───────┼──────────────────┼──────────────────┼──────────────────┤
   │     3 │         14156.74 │         16895.72 │         16895.72 │
   └───────┴──────────────────┴──────────────────┴──────────────────┘

   Results from otel-ai-chatbot-backend dataset (last 1 hour):
   - P50: 14.2 seconds
   - P95: 16.9 seconds
   - P99: 16.9 seconds
   - Count: 3 requests

   Analysis: P95 latency of 16.9 seconds is extremely concerning!
   User experience is severely degraded at this latency level.
   ```

2. Ask for more specific analysis:
   ```
   Using Honeycomb, break down the latency by span name. Which operation is the slowest?
   ```

   Expected output:
   ```
   Latency breakdown by operation (P95):

   1. POST - P95: 17,031ms (HTTP endpoint)
   2. rag.generate_response - P95: 17,029ms (RAG generation)
   3. rag.llm_generation - P95: 16,897ms (LLM calls)
   4. chat anthropic.claude-3-5-sonnet - P95: 16,895ms (Claude API)
   5. rag.vector_search - P95: 218ms (Vector database)
   6. BedrockRuntime.InvokeModel - P95: 150ms (Bedrock SDK)

   Analysis: The Claude API calls (via Bedrock) are taking nearly 17 seconds,
   which accounts for ~99% of total request time. The vector search is fast
   (218ms), so the bottleneck is clearly the LLM generation phase.
   ```

3. Check for errors:
   ```
   Query Honeycomb for any errors in the last hour.
   ```

   Expected output:
   ```
   ┌───────┐
   │ COUNT │
   ├───────┤
   │     0 │
   └───────┘

   No errors found in the last hour.

   Analysis: The application is running without errors, which is good.
   The performance issue is not caused by errors or exceptions, but rather
   by slow LLM response times.
   ```

::alert[**Natural Language Queries**: Notice you don't need to learn Honeycomb's query syntax. Claude Code translates your natural language request into proper Honeycomb queries using the MCP server.]{type="success"}

## Step 5: Ask Claude Code to Diagnose the Issue

Now let's have Claude Code analyze the infrastructure and propose a solution.

1. Provide context and ask for diagnosis:
   ```
   I'm seeing P95 latency of 16.9 seconds for my otel-ai-chatbot application.
   The Claude API calls (via Bedrock) take 16,895ms P95 and vector search takes 218ms P95.
   Using the Pulumi MCP server, inspect the current infrastructure configuration
   and tell me what could be causing such high LLM latency.
   ```

   Claude Code will:
   - Connect to Pulumi MCP server
   - Inspect the current stack state
   - Examine ECS task definition and Bedrock configuration
   - Analyze the application code for LLM configuration
   - Correlate with observed latency patterns

   Expected response:
   ```
   Analyzing infrastructure and application configuration...

   Current Configuration:
   - Model: anthropic.claude-3-5-sonnet-20240620-v1:0
   - ECS Task: CPU 256 units, Memory 512 MB
   - No response streaming enabled
   - No caching layer for similar queries

   Diagnosis:
   The 16.9 second P95 latency is caused by the LLM generation phase.
   The Claude Sonnet 3.5 model is taking nearly 17 seconds to generate
   responses. This is unusually high and suggests:

   1. Large context windows being sent to the model
   2. Very long response generation (high max_tokens setting)
   3. No streaming enabled - users wait for complete response
   4. Potential RAG context including too many documents
   5. No response caching for similar questions

   The infrastructure (ECS task) is NOT the bottleneck here. The task
   is spending 99% of its time waiting for Bedrock API responses.

   Recommendations (in order of impact):

   1. Enable streaming responses (immediate UX improvement)
      - Users see partial results while generation continues
      - Perceived latency drops significantly

   2. Optimize RAG context size
      - Limit number of retrieved documents
      - Reduce chunk sizes passed to LLM

   3. Implement response caching
      - Cache responses for similar/repeated questions
      - Reduce API calls for common queries

   4. Consider model alternatives
      - Claude Haiku: Faster, cheaper, slightly less capable
      - Or use Claude Sonnet with streaming

   Expected Impact:
   - With streaming: Perceived latency 16.9s → ~2s (time to first token)
   - With optimized context: Total latency 16.9s → ~8-10s (-40-50%)
   - With caching: 80% of requests served instantly from cache
   ```

::alert[**This is the key insight**: The AI agent correlated observability data (traces) with application configuration to diagnose that the performance issue is caused by LLM generation latency, not infrastructure resource constraints. The solution requires application-level changes, not infrastructure scaling.]{type="success"}

## Step 6: Invoke Pulumi Neo for Code Generation

Now let's use **Pulumi Neo**, Pulumi's AI agent, to generate the infrastructure code change.

1. Ask Claude Code to generate the fix using Pulumi Neo:
   ```
   Using the Pulumi MCP server, invoke Pulumi Neo to generate a patch
   that increases the ECS task CPU from 512 to 1024 units.
   Show me the diff before I apply it.
   ```

   Claude Code will:
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
   ```

   Then ask Claude Code:
   ```
   Apply the Pulumi Neo patch to increase ECS task CPU
   ```

   Claude Code will:
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
   ```
   Using Honeycomb, compare P95 latency for chat requests before and after the deployment.
   Use the deployment time as the comparison point.
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

Now ask Claude Code for additional recommendations:

```
Based on the observability data in Honeycomb and the current infrastructure in Pulumi,
what other optimizations could improve performance or reduce costs?
```

Claude Code might suggest:
- **Implement caching**: Cache OpenSearch results for common queries
- **Optimize OpenSearch**: Increase shard count or instance size
- **Add autoscaling**: Scale ECS tasks based on CPU utilization
- **Implement rate limiting**: Protect against traffic spikes
- **Add CDN**: Cache static frontend assets on CloudFront
- **Optimize embeddings**: Reduce vector dimensions (1536 → 768)

You can then ask Claude Code to help implement any of these optimizations using the same workflow!

## Module Summary

Congratulations! You've successfully:

✅ Configured MCP servers for Honeycomb and Pulumi
✅ Connected Claude Code to your observability and infrastructure data
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

**Symptom**: Claude Code says "Honeycomb MCP server unavailable" or cannot connect

**Solution**:
1. Check that the MCP server is configured:
   ```bash
   claude mcp list
   ```

2. Re-authenticate with Honeycomb (refresh OAuth):

   If your OAuth token has expired or authentication failed, you may need to re-authenticate:
   - Ask Claude Code to query Honeycomb data again
   - Follow the OAuth flow when prompted
   - Grant the necessary permissions

3. Try removing and re-adding the MCP server:
   ```bash
   claude mcp remove honeycomb
   claude mcp add honeycomb --transport http https://mcp.honeycomb.io/mcp
   ```

   Then re-authenticate using the OAuth flow when you make your first query.

### Pulumi Neo Not Available

**Symptom**: Claude Code says "Pulumi Neo is not enabled for this stack"

**Solution**:
1. Verify you're on Pulumi Cloud (not self-hosted Pulumi backend)
2. Check your Pulumi organization has Neo enabled (may require paid plan)
3. Contact Pulumi support to enable Neo access
4. Verify the Pulumi MCP server is properly authenticated:
   ```bash
   pulumi whoami
   ```

### Claude Code Returns Incorrect Analysis

**Symptom**: AI agent makes wrong conclusions from data

**Solution**:
- **Provide more context**: Be explicit about what you're observing
- **Ask follow-up questions**: "Why did you conclude X?"
- **Verify data sources**: Check that MCP servers are returning correct data
- **Use specific time ranges**: "last hour" vs "last 24 hours" can dramatically change results

---

## Additional Resources

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Honeycomb MCP Server Documentation](https://docs.honeycomb.io/integrations/mcp/configuration-guide/)
- [Pulumi MCP Server Documentation](https://www.pulumi.com/docs/iac/using-pulumi/mcp-server/)
- [Pulumi Neo Documentation](https://www.pulumi.com/docs/pulumi-cloud/copilot/neo/)
- [Claude Code Documentation](https://claude.ai/code)
- [MCP Compatible AI Tools](https://docs.anthropic.com/en/docs/agents-and-tools/mcp)
- [Building Agentic Workflows (Andrew Ng)](https://www.deeplearning.ai/the-batch/how-agents-can-improve-llm-performance/)
