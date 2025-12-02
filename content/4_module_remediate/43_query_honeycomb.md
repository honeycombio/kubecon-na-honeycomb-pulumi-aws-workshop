---
title: "Step 3: Query Honeycomb Data"
weight: 63
---

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
    ┌───────┬──────────────────┐
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
    ┌──────────────────┬───────┬──────────────────┬────────────────────────────────────────────────┐
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