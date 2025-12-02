---
title: "Step 6: Ask Pulumi Neo for Detailed Solution Recommendations"
weight: 66
---

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
    ⎿ Sent follow-up message to task https://app.pulumi.com/<your-org>/neo/tasks/<task-id>
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
    | P95 Latency     | 19.6s  | 50ms              | 5s                 | 97% / 75% ✨  |
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
    
    View full task details: https://app.pulumi.com/<your-org>/neo/tasks/<task-id>
    
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