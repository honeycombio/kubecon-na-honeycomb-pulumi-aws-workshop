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

## Step 0: Prepare some Honeycomb Data

Head over to the UI of our AI Chatbot application and interact with it a bit to generate some observability data in Honeycomb. I would say make around 5-10 requests to the chatbot by asking it various questions. This will ensure we have some data to query in the next steps.

## Step 4: Query Honeycomb Data via Claude Code

Now let's use Claude Code to query the observability data we collected in Module 3.

1. Ask Claude Code about recent application performance:
   ```
   Using the Honeycomb MCP server, show me the P95 latency for successful chat requests
   (status code 200) in the last hour for the otel-ai-chatbot-backend dataset
   ```

   Claude Code will:
   - Connect to Honeycomb MCP server
   - Construct appropriate Honeycomb query (filtering for HTTP 200 responses)
   - Execute query and return results
   - Format results in a readable way

   Expected output:
   ```
   ⏺ I'll help you query the P95 latency for successful chat requests from Honeycomb. Let me start by getting the workspace context and then run
    the query.
    ⎿ HONEYCOMB WORKSPACE CONTEXT
    ============================
    … +22 lines (ctrl+o to expand)
    
    ⏺ honeycomb - get_dataset_columns (MCP)(environment_slug: "otel-ai-chatbot-backend", dataset_slug: "otel-ai-chatbot-backend")
    ⎿ # Page: 1 | Items per page: 1000 | Total items: 172 | Total pages: 1 | Has next page: false | Has previous page: false | All columns: fals
    e | Dataset: otel-ai-chatbot-backend | Environment: otel-ai-chatbot-backend
    … +242 lines (ctrl+o to expand)
    
    
    ⏺ Now I'll query the P95 latency for successful chat requests (status code 200) in the last hour:
    
    ⏺ honeycomb - run_query (MCP)(environment_slug: "otel-ai-chatbot-backend", dataset_slug: "otel-ai-chatbot-backend", query_spec:
    {"calculations":[{"op":"P95","column":"duration_ms"},{"op":"COUNT"}],"filters":[{"column":"http.status_code","op":"=",
    "value":200}],"time_range":3600}, output_format: "ascii")
    ⎿ ┌───────┬──────────────────┐
       │ COUNT │ P95(duration_ms) │
       ├───────┼──────────────────┤
    … +43 lines (ctrl+o to expand)
    
    ⏺ P95 Latency Results for Successful Chat Requests
    
    Based on the last hour of data from the otel-ai-chatbot-backend dataset:
    
    Key Metrics:
    - P95 Latency: 17,552.49 ms (~17.5 seconds)
      - Request Count: 127 successful requests (HTTP 200)
    
    Observations:
    - The latency remains relatively stable throughout the hour at around 2ms
      - There's a significant spike at the end of the time range reaching ~17.5 seconds
      - Request volume shows consistent traffic with some increased activity towards the end
    
    The query filtered for http.status_code = 200 to capture only successful chat requests over the past 3600 seconds (1 hour).
    
    You can view the full query results here:
    https://ui.honeycomb.io/ediri/environments/otel-ai-chatbot-backend/datasets/otel-ai-chatbot-backend/result/p4oFfcKjHSN
   ```

2. Ask for more specific analysis:
   ```
   Using Honeycomb, break down the latency by span name for successful requests.
    Which operation is the slowest?
   ```

   Expected output:
   ```
    ⏺ I'll query Honeycomb to break down the latency by span name for successful requests.
    
    ⏺ honeycomb - run_query (MCP)(environment_slug: "otel-ai-chatbot-backend", dataset_slug: "otel-ai-chatbot-backend", query_spec:
    {"calculations":[{"op":"P95","column":"duration_ms"},{"op":"AVG","column":"duration_ms"},{"op":"COUNT"}],"filters":[{"
    column":"http.status_code","op":"=","value":200}],"breakdowns":["name"],"orders":[{"op":"P95","column":"duration_ms","
    order":"descending"}],"limit":20,"time_range":3600}, output_format: "ascii")
    ⎿ ┌──────────────────┬───────┬──────────────────┬────────────────────────────────────────────────┐
    │ AVG(duration_ms) │ COUNT │ P95(duration_ms) │ name                                           │
    ├──────────────────┼───────┼──────────────────┼────────────────────────────────────────────────┤
    … +206 lines (ctrl+o to expand)
    
    ⏺ Latency Breakdown by Span Name
    
    Here's the breakdown of latency for successful requests (HTTP 200), sorted by P95 latency:
    
    | Span Name                                      | P95 Latency           | Avg Latency         | Count |
      |------------------------------------------------|-----------------------|---------------------|-------|
    | chat anthropic.claude-3-5-sonnet-20240620-v1:0 | 19,621.77 ms (~19.6s) | 16,977.87 ms (~17s) | 7     |
    | POST                                           | 19,202.18 ms (~19.2s) | 8,583.47 ms (~8.6s) | 14    |
    | BedrockRuntime.InvokeModel                     | 186.00 ms             | 115.68 ms           | 7     |
    | GET                                            | 2.60 ms               | 1.94 ms             | 98    |
    
    Slowest Operation: Chat with Claude 3.5 Sonnet
    
    The chat anthropic.claude-3-5-sonnet-20240620-v1:0 operation is by far the slowest, with:
    - P95 latency of ~19.6 seconds
      - Average latency of ~17 seconds
      - Only 7 requests in the past hour
    
    This represents the LLM generation phase where the chatbot is invoking Claude 3.5 Sonnet on AWS Bedrock to generate responses. The high
    latency is expected for LLM inference, especially with:
    - Large context windows (retrieving documentation chunks)
      - Streaming responses
      - Token generation overhead
    
    The POST endpoint (the overall HTTP request handler) shows similar P95 latency, which makes sense since it encompasses the chat operation
    along with other processing steps like vector search and context formatting.
    
    View full query results:
    https://ui.honeycomb.io/ediri/environments/otel-ai-chatbot-backend/datasets/otel-ai-chatbot-backend/result/dswrYHfTwsP
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

## Step 5: Use Pulumi Neo to Diagnose the Issue

Now let's use **Pulumi Neo** (via Claude Code) to analyze the infrastructure and application based on our Honeycomb findings.

1. Provide Honeycomb findings to Pulumi Neo:
   ```
   Using the Pulumi MCP server, ask Pulumi Neo to analyze stack "otel-ai-chatbot-infra/ws"
   with these Honeycomb findings.
   ```

   Claude Code will:
   - Connect to Pulumi MCP server
   - Invoke Pulumi Neo for stack analysis
   - Neo inspects infrastructure state (ECS, Bedrock config)
   - Neo analyzes application code structure
   - Neo correlates infrastructure with observed latency patterns
   - Neo provides root cause analysis

   Expected response (Neo's comprehensive analysis):
   ~~~
   ⏺ I'll use Pulumi Neo to analyze the stack with the Honeycomb findings about the high latency we discovered.

    ⏺ pulumi - neo-bridge (MCP)(query: "Analyze the infrastructure for the otel-ai-chatbot application and review it based on these observability
    findings from Honeycomb:\n\n**Performance Analysis:**\n- P95 latency for successful chat requests: 17.5 seconds\n-
    Slowest operation: \"chat anthropic.claude-3-5-sonnet-20240620-v1:0\" with P95 of 19.6 seconds (avg 17 seconds)\n- POST
    endpoint P95 latency: 19.2 seconds\n- Only 7 LLM chat requests in the past hour\n- BedrockRuntime.InvokeModel: 186ms
    average\n- GET requests are fast: 2.6ms P95\n\n**Key Observations:**\n- The Claude 3.5 Sonnet LLM inference on AWS
    Bedrock is the primary bottleneck\n- Very high latency (~20 seconds) for chat operations\n- Low request volume (7 chat
    requests/hour)\n\nPlease analyze the current infrastructure configuration and suggest optimizations to:\n1. Reduce LLM
    inference latency\n2. Improve overall application performance\n3. Optimize for better user experience given these
    latency patterns\n4. Consider infrastructure changes like compute resources, caching, or architectural improvements",
    stack: {"name":"ws","project":"otel-ai-chatbot-infra"})
    ⎿ Neo task launched at: https://app.pulumi.com/ediri/neo/tasks/ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ Let me check for updates on the Neo analysis:
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ I'll analyze the infrastructure for the otel-ai-chatbot application and provide recommendations based on the observability findings. Let m
    e start by gathering information about the current infrastructure setup.
    
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Now let me retrieve the source code to examine the infrastructure configuration in detail:
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Now let me check the application configuration and RAG service to understand the full architecture:
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Now let me check the package.json to understand the dependencies and check if there's any caching mechanism:
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Based on my analysis of the infrastructure and observability data, I can now provide you with a comprehensive analysis and recommendations
    . Let me create a detailed report:
    … +261 lines (ctrl+o to expand)
    
    
    ⏺ Pulumi Neo Analysis Complete!
    
    Neo has finished analyzing the otel-ai-chatbot-infra/ws stack with the Honeycomb observability findings. Here are the key insights:
    
    🔍 Root Cause Analysis
    
    Current Infrastructure:
    - ECS Fargate: 512 CPU (0.5 vCPU), 1024 MB memory
      - 1 task instance (no auto-scaling)
      - Claude 3.5 Sonnet model on Bedrock
      - OpenSearch: 2x m8g.large instances
      - No caching layer
    
    Primary Bottleneck: The 20-second latency is from LLM inference (Claude 3.5 Sonnet), but there's no caching to prevent repeated expensive
    calls.
    
    🎯 Top Recommendations (Priority Order)
    
    Phase 1 - Highest Impact (Immediate):
    1. Add ElastiCache Redis for response caching → 97% latency reduction on cache hits
       2. Switch to Claude 3.5 Haiku → 75% latency reduction (19.6s → 5s)
       3. Enable streaming responses → 90% better perceived performance
       4. Reduce context docs from 5 to 3 → Faster vector search
    
    Phase 2 - Infrastructure (Short-term):
    5. Add Bedrock VPC endpoint → Reduce network latency
       6. Scale up ECS tasks → 1024 CPU, 2048 MB memory
       7. Enable ECS auto-scaling → Handle traffic spikes
       8. Optimize OpenSearch → Switch to r6g.large (memory-optimized)
    
    📊 Expected Results
    
    | Scenario              | Current P95 | Expected P95 | Improvement |
      |-----------------------|-------------|--------------|-------------|
    | Cache hit             | 19.6s       | 0.5s         | 97% ✨       |
    | Cache miss (Haiku)    | 19.6s       | 5s           | 75%         |
    | Streaming (perceived) | 19.6s       | 2s TTFB      | 90%         |
    
    💰 Cost Impact
    
    - Current: ~$150-200/month
      - After optimizations: +$34/month (~17% increase)
      - ROI: 75-97% latency reduction for 17% cost increase
    
    📋 Next Steps
    
    Neo is ready to implement these changes. Would you like Neo to:
    1. Start with Phase 1 (caching + model switch)?
       2. Create infrastructure patches for review?
       3. Implement specific optimizations?
    
    View the full analysis: https://app.pulumi.com/ediri/neo/tasks/ccd742a6-0fd6-4d03-9751-359525af019c
   ~~~

::alert[**Neo's Power**: Notice how Neo analyzed the entire stack - infrastructure state, application code structure, and correlated with Honeycomb metrics - to provide a comprehensive diagnosis. It correctly identified this as an application-level issue, not infrastructure.]{type="success"}

## Step 6: Ask Pulumi Neo for Detailed Solution Recommendations

Neo has diagnosed the root cause (application-level LLM latency). Now let's ask for detailed, prioritized recommendations.

1. Request solution recommendations from Pulumi Neo:
   ```
   Based on your diagnosis, please provide detailed recommendations for follwowing solution:
   1. Response Caching Strategy (Highest Impact)
   ```

   Expected response (Neo's detailed recommendations):
   ~~~
   ⏺ I'll ask Pulumi Neo to provide detailed, actionable recommendations specifically for implementing the response caching strategy.

    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c", query: "Please provide detailed, implementation-ready recommendations
    for the Response Caching Strategy. Include:\n\n1. **Infrastructure Setup:**\n   - Complete Pulumi code for ElastiCache
    Redis configuration\n   - Network configuration (VPC, security groups, subnets)\n   - High availability and backup
    configuration\n   - Connection pooling setup\n\n2. **Application-Level Implementation:**\n   - Detailed caching strategy
    for different types of requests\n   - Cache key design and hashing strategy\n   - TTL policies for different content
    types\n   - Code examples for integrating Redis in the Node.js application\n   - Error handling and cache fallback
    strategies\n\n3. **Multi-Layer Caching Architecture:**\n   - Response caching (full LLM responses)\n   - Vector search
    result caching\n   - Embedding caching\n   - Cache invalidation strategies\n\n4. **Performance Optimization:**\n   -
    Cache warming strategies\n   - Cache hit rate monitoring\n   - Memory sizing recommendations\n   - Connection
    optimization\n\n5. **Monitoring & Observability:**\n   - CloudWatch metrics for cache performance\n   - OpenTelemetry
    instrumentation for cache operations\n   - Honeycomb integration for cache analytics\n   - Key metrics to track (hit
    rate, latency, etc.)\n\nPlease provide concrete code examples and configuration that can be directly implemented.")
    ⎿ Sent follow-up message to task https://app.pulumi.com/ediri/neo/tasks/ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Based on my analysis of the infrastructure and observability data, I can now provide you with a comprehensive analysis and recommendations
    . Let me create a detailed report:
    … +261 lines (ctrl+o to expand)
    
    ⎿ I'll provide a comprehensive, implementation-ready response caching strategy for your otel-ai-chatbot application.

    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Perfect! Now let me create a summary document of all the files created and the implementation:
    
         ## Summary
         … +195 lines (ctrl+o to expand)
    
    ⏺ 🎉 Comprehensive Response Caching Strategy Complete!
    
    Pulumi Neo has finished creating a detailed, production-ready implementation for the response caching strategy. Here's what was delivered:
    
    📋 Complete Implementation Package
    
    Infrastructure (Pulumi)
    
    - ✅ ElastiCache Redis Cluster with Multi-AZ replication
        - 1 primary + 1 replica for high availability
        - Automatic failover and backup (7-day retention)
        - CloudWatch alarms for CPU, memory, evictions, hit rate
        - Optimized parameters for performance
      - ✅ Network Configuration
          - Security groups with proper isolation
          - Subnet group configuration
          - VPC integration with ECS tasks
    
    Application Layer (Node.js)
    
    - ✅ cacheService.js (17KB) - Core caching engine
        - Circuit breaker pattern for resilience
        - Connection pooling (2-10 connections)
        - 3-layer cache API: Response, Vector Search, Embeddings
        - Automatic retry with exponential backoff
      - ✅ ragServiceCached.js (15KB) - Drop-in RAG replacement
          - Transparent multi-layer caching
          - Full OpenTelemetry tracing
          - Graceful degradation
      - ✅ vectorStoreCached.js (12KB) - Embedding cache
          - Caches Bedrock Titan embeddings
          - 80-90% latency reduction for repeated queries
    
    Monitoring & Observability
    
    - ✅ cacheMetrics.js - OpenTelemetry instrumentation
        - Hit/miss counters by layer
        - Latency histograms
        - Cache size tracking
        - Honeycomb-ready metrics
      - ✅ Cache Management API (routes/cache.js)
          - GET /api/cache/stats - Real-time statistics
          - GET /api/cache/health - Health checks
          - POST /api/cache/invalidate - Cache clearing
          - POST /api/cache/warm - Pre-warming
    
    Cache Warming
    
    - ✅ cacheWarming.js (9KB)
        - 20+ pre-defined common questions
        - Automatic startup warming
        - Scheduled warming jobs
        - Query log analysis
    
    Documentation
    
    - ✅ CACHING_IMPLEMENTATION.md (16KB) - Complete guide
        - Architecture diagrams
        - Setup instructions
        - API documentation
        - Troubleshooting guide
        - Performance tuning tips
    
    🎯 Expected Impact
    
    | Metric          | Before | After (Cache Hit) | After (Cache Miss) | Improvement   |
      |-----------------|--------|-------------------|--------------------|---------------|
    | P95 Latency     | 19.6s  | 50ms              | 5s                 | 97% / 75% ✨   |
    | Bedrock Calls   | 100%   | 30%               | 100%               | 70% reduction |
    | User Experience | Poor   | Excellent         | Good               | Dramatic      |
    
    💰 Cost Impact
    
    - Infrastructure: +$52/month (ElastiCache)
      - Savings: -$15/month (70% fewer Bedrock calls)
      - Net: +$37/month for 97% latency reduction 🚀
    
    🚀 Quick Deployment
    
    # 1. Deploy infrastructure
    cd pulumi && pulumi up
    
    # 2. Install dependencies
    npm install
    
    # 3. Verify deployment
    curl http://your-alb/api/cache/health
    
    # 4. Warm the cache
    curl -X POST http://your-alb/api/cache/warm \
    -H "Content-Type: application/json" \
    -d '{"maxQuestions": 20}'
    
    📊 Monitoring in Honeycomb
    
    Once deployed, you can track cache performance:
    - Cache hit rates by layer
      - Latency improvements (cached vs uncached)
      - Bedrock API call reduction
      - End-to-end performance gains
    
    View full task details: https://app.pulumi.com/ediri/neo/tasks/ccd742a6-0fd6-4d03-9751-359525af019c
    
    All code is production-ready with comprehensive error handling, resilience patterns, and full observability integration. Would you like me to
    help you deploy this solution or explore any specific aspect in more detail?
   ~~~

2. Review Neo's recommendations:
   - ✓ Prioritized by impact (Streaming first = 85% perceived improvement)
   - ✓ Actionable and specific (Exact files and line numbers provided)
   - ✓ Explains trade-offs (Quality vs speed, code vs infrastructure)
   - ✓ Addresses both quick wins (streaming) and long-term improvements
   - ✓ Provides cost implications for each solution
   - ✓ Includes implementation timeline and strategy

::alert[**The Agentic Workflow**: Notice the flow: Honeycomb data → Neo diagnosis (Step 5) → Neo recommendations (Step 6) → Neo code generation (Step 7). This is a complete AI-driven operations loop where the AI agent reasons across observability, infrastructure, and application code to solve problems autonomously with human oversight.]{type="success"}

## Step 7: Request Code Generation and PR Creation

Let's ask Neo to implement the highest-impact solution: **Enable Streaming Responses**.

1. Ask Pulumi Neo to generate code patches and create a PR:
   ```
   Using the git repository github.com/dirien/ai-workshop and the Pulumi MCP server to create now a PR for this solution
   ```

   **Note**: Neo will analyze the git repository, generate code patches, and create a Pull Request
   automatically. You'll be asked to approve the changes before Neo creates the PR.

   Neo's actual response:
   ~~~
   ⏺ I'll help you create a PR for the caching solution using Pulumi Neo and the GitHub repository.

    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c", query: "Please create a pull request for the caching implementation in
    the GitHub repository github.com/dirien/ai-workshop.\n\nThe PR should include all the files we created for the response
    caching strategy:\n\n**Infrastructure:**\n- pulumi/cache-infrastructure.ts (new file)\n- pulumi/index.ts (updated to
    integrate cache)\n\n**Application Services:**\n- server/services/cacheService.js (new file)\n-
    server/services/ragServiceCached.js (new file)\n- server/services/vectorStoreCached.js (new file)\n\n**Monitoring &
    Utilities:**\n- server/utils/cacheMetrics.js (new file)\n- server/utils/cacheWarming.js (new file)\n-
    server/routes/cache.js (new file)\n\n**Integration Updates:**\n- server/index.js (updated)\n- server/routes/chat.js
    (updated)\n- package.json (updated with Redis dependency)\n\n**Documentation:**\n- CACHING_IMPLEMENTATION.md (new
    file)\n\n**PR Details:**\n- Title: \"feat: Implement multi-layer Redis caching for 97% latency reduction\"\n-
    Description: Include a summary of the changes, expected performance improvements, cost analysis, and deployment
    instructions\n- Base branch: main (or the default branch)\n- Create a feature branch:
    feat/redis-caching-implementation\n\nPlease create all the necessary files, commit them to a new branch, and open the
    pull request.")
    ⎿ Sent follow-up message to task https://app.pulumi.com/ediri/neo/tasks/ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Perfect! Now let me create a summary document of all the files created and the implementation:
    
         ## Summary
         … +195 lines (ctrl+o to expand)
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ I'll create a comprehensive pull request with all the caching implementation files. Let me prepare the PR with a detailed description and
    all the changes.
    ⎿ May I open a Pull Request with the following title: 'feat: Implement multi-layer Redis caching for 97% latency reduction'?
    
         Neo is waiting for your approval.
    
    ⏺ Neo is requesting approval to create a pull request with the title:
    
    "feat: Implement multi-layer Redis caching for 97% latency reduction"
    
    This PR will include:
    - All infrastructure code (ElastiCache Redis setup)
      - Application caching services (cacheService.js, ragServiceCached.js, vectorStoreCached.js)
      - Monitoring and metrics (OpenTelemetry integration)
      - Cache management API endpoints
      - Cache warming utilities
      - Complete documentation (CACHING_IMPLEMENTATION.md)
      - Updated package.json with Redis dependencies
    
    Would you like me to approve this and proceed with creating the pull request to the github.com/dirien/ai-workshop repository?
    
    > yes
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c", approval: true)
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ I'll create a comprehensive pull request with all the caching implementation files. Let me prepare the PR with a detailed description and
    all the changes.
    ⎿ May I open a Pull Request with the following title: 'feat: Implement multi-layer Redis caching for 97% latency reduction'?
    
         Neo is waiting for your approval.
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ I don't understand if you approved or not. Neo is waiting for approval. Please call this tool again with approval=true to approve or appro
    val=false to reject.
    
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c", approval: true)
    ⎿ Approval sent: APPROVED
    ⎿ ⏳ Neo is still processing your request. This can take some time for complex infrastructure tasks.
    
         To check for updates, call this tool again with the same taskId (no need to provide a query).
    
    ⏺ pulumi - neo-bridge (MCP)(taskId: "ccd742a6-0fd6-4d03-9751-359525af019c")
    ⎿ Polling task ccd742a6-0fd6-4d03-9751-359525af019c
    ⎿ Perfect! I've successfully created Pull Request #2 in the `dirien/ai-workshop` repository.
    
         ## 🎉 Pull Request Created Successfully!
         … +68 lines (ctrl+o to expand)
    
    ⏺ 🎉 Pull Request Successfully Created!
    
    PR #2 has been opened in the dirien/ai-workshop repository with the complete Redis caching implementation.
    
    🔗 Pull Request Details
    
    - Repository: github.com/dirien/ai-workshop
      - PR Number: https://github.com/dirien/ai-workshop/pull/2
      - Title: "feat: Implement multi-layer Redis caching for 97% latency reduction"
      - Branch: Auto-created feature branch
    
    📦 Files Included (12 total)
    
    Infrastructure:
    - pulumi/cache-infrastructure.ts (new)
      - pulumi/index.ts (updated)
    
    Application Services:
    - server/services/cacheService.js (new)
      - server/services/ragServiceCached.js (new)
      - server/services/vectorStoreCached.js (new)
    
    Monitoring & Management:
    - server/utils/cacheMetrics.js (new)
      - server/utils/cacheWarming.js (new)
      - server/routes/cache.js (new)
    
    Integration:
    - server/index.js (updated)
      - server/routes/chat.js (updated)
      - package.json (updated)
    
    Documentation:
    - CACHING_IMPLEMENTATION.md (new)
    
    🎯 Expected Impact
    
    | Metric            | Before | After (Cache Hit) | Improvement                       |
      |-------------------|--------|-------------------|-----------------------------------|
    | P95 Latency       | 19.6s  | 50ms              | 97% ✨                             |
    | Bedrock API Calls | 100%   | 30%               | 70% reduction                     |
    | Monthly Cost      | ~$150  | ~$187             | +$37 for massive performance gain |
    
    🚀 Next Steps
    
    1. Review the PR at https://github.com/dirien/ai-workshop/pull/2
       2. Test in staging environment
       3. Monitor cache hit rates and latency in Honeycomb
       4. Merge when ready for production deployment
    
    The complete implementation is production-ready with comprehensive monitoring, error handling, and documentation! 🎊
   ~~~

::alert[**The Complete Agentic Loop**: Neo just demonstrated end-to-end automation - from observability data to PR creation. It analyzed Honeycomb metrics (Step 4), diagnosed the issue (Step 5), provided recommendations (Step 6), generated code patches, and created a production-ready PR (Step 7). This is AI-powered infrastructure management in action with human-in-the-loop oversight.]{type="success"}

## Step 8: Review the Pull Request

1. Visit the Pull Request URL provided by Neo:
   ```
   https://github.com/dirien/ai-workshop/pull/2
   ```

2. Review the comprehensive PR that Neo created. The PR includes:

   **Infrastructure (Pulumi):**
   - `pulumi/cache-infrastructure.ts` - ElastiCache Redis cluster with multi-AZ replication
   - `pulumi/index.ts` - Updated to integrate cache infrastructure

   **Application Services:**
   - `server/services/cacheService.js` - Multi-layer caching engine with circuit breaker
   - `server/services/ragServiceCached.js` - Drop-in replacement RAG service with caching
   - `server/services/vectorStoreCached.js` - Embedding cache for Bedrock

   **Monitoring & Management:**
   - `server/utils/cacheMetrics.js` - OpenTelemetry instrumentation
   - `server/utils/cacheWarming.js` - Automated cache warming utility
   - `server/routes/cache.js` - Cache management API endpoints

   **Documentation:**
   - `CACHING_IMPLEMENTATION.md` - Complete implementation guide

3. The PR description includes:
   - **Problem Statement**: 19.6s P95 latency identified via Honeycomb
   - **Solution**: Multi-layer Redis caching (Response + Vector Search + Embeddings)
   - **Expected Impact**: 97% latency reduction for cache hits (19.6s → 50ms)
   - **Cost Analysis**: +$37/month for 97% performance improvement
   - **Deployment Instructions**: Step-by-step guide
   - **Monitoring Strategy**: CloudWatch alarms and Honeycomb queries

::alert[**Human-in-the-Loop**: Notice how Neo created a complete PR with all files, documentation, and clear explanations - but it's waiting for YOUR approval. You maintain full control over what gets deployed to production.]{type="success"}

## Step 9: Understanding the Complete Impact

Let's understand what the implemented caching solution will deliver:

### Performance Improvements:

**Before Caching:**
```
User Request → Vector Search (120ms) → LLM Generation (19.6s) → Response
              └─ Total: ~19.6 seconds for every request
```

**After Caching (Cache Hit - ~90% of requests):**
```
User Request → Cache Lookup (5ms) → Response from Cache (50ms)
              └─ Total: ~50ms (97% improvement!)
```

**After Caching (Cache Miss - ~10% of requests):**
```
User Request → Vector Search (120ms) → LLM Generation (19.6s) → Cache Store → Response
              └─ Total: ~19.6 seconds (same as before, but populates cache)
```

### What You'll See in Honeycomb:

1. **Query to verify caching is working:**
   ```
   Using Honeycomb, show me cache hit rates by layer for the otel-ai-chatbot-backend dataset
   ```

   Expected result after deployment:
   ```
   Cache Statistics (after 24 hours):
   - Response Cache Hit Rate: 85-90%
   - Vector Search Cache Hit Rate: 88-92%
   - Embedding Cache Hit Rate: 95-98%
   - Average Response Time (cached): 45-60ms
   - Average Response Time (uncached): 18-20s
   - Bedrock API Call Reduction: 70%
   ```

2. **New OpenTelemetry metrics tracked:**
   ```
   - cache.hit (counter by layer)
   - cache.miss (counter by layer)
   - cache.latency (histogram)
   - cache.value_size (histogram)
   - rag.cache_hit (boolean attribute)
   ```

3. **Cache Management Endpoints:**
   ```bash
   # Real-time cache statistics
   curl http://your-alb/api/cache/stats

   # Cache health check
   curl http://your-alb/api/cache/health

   # Manually warm cache with common questions
   curl -X POST http://your-alb/api/cache/warm \
     -H "Content-Type: application/json" \
     -d '{"maxQuestions": 20}'
   ```

## Module Summary

Congratulations! You've successfully:

* ✅ Configured MCP servers for Honeycomb and Pulumi (OAuth-based, no API keys!)
* ✅ Connected Claude Code to your observability and infrastructure data
* ✅ Used natural language to query Honeycomb traces
* ✅ Asked AI agent to diagnose performance bottleneck (LLM latency, not infrastructure)
* ✅ Passed diagnosis to Pulumi Neo for comprehensive analysis
* ✅ Neo analyzed BOTH infrastructure and application code
* ✅ Received prioritized recommendations with impact analysis
* ✅ Neo generated code patches and created a Pull Request (human-in-the-loop)
* ✅ Understood streaming solution reduces perceived latency by 90%
* ✅ Learned the end-to-end agentic workflow for AI-powered operations

## What's Next?

In the **Cleanup** section, you'll tear down all the resources you've deployed to avoid ongoing costs.

---
