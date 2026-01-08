---
title: "Step 5: Use Pulumi Neo to Diagnose the Issue"
weight: 65
---

Now let's use **Pulumi Neo** (via Kiro CLI) to analyze the infrastructure and application based on our Honeycomb findings.

1. Provide Honeycomb findings to Pulumi Neo:
   ```
   Using the Pulumi MCP server, ask Pulumi Neo to analyze stack "otel-ai-chatbot-infra/ws"
   with these Honeycomb findings.
   ```

   Kiro CLI will:
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
    ⎿ Neo task launched at: https://app.pulumi.com/<your-org>/neo/tasks/<task-id>
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
    | Cache hit             | 19.6s       | 0.5s         | 97% ✨      |
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
    
    View the full analysis: https://app.pulumi.com/<your-org>/neo/tasks/<task-id>
   ~~~

::alert[**Neo's Power**: Notice how Neo analyzed the entire stack - infrastructure state, application code structure, and correlated with Honeycomb metrics - to provide a comprehensive diagnosis. It correctly identified this as an application-level issue, not infrastructure.]{type="success"}