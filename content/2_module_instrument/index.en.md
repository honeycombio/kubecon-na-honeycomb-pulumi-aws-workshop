---
title: "Module 2: Configure Observability"
weight: 40
---

In this module, you'll explore the OpenTelemetry instrumentation that's already built into the GenAI application and configure it to send telemetry data to Honeycomb. This demonstrates a **production-ready pattern** where observability is a first-class citizen from day one, not bolted on later.

## Module Overview

**Duration:** 15 minutes

**Objectives:**
- Understand the existing OpenTelemetry instrumentation architecture
- Review auto-instrumentation and custom tracing for GenAI workloads
- Verify Honeycomb configuration in the deployed application
- Generate traffic and confirm telemetry is flowing to Honeycomb
- Explore the trace structure and GenAI-specific attributes

## Key Concept: Observability From Day One

Unlike traditional approaches where instrumentation is added after deployment, this application demonstrates **observability-first architecture**:

✅ OpenTelemetry instrumentation exists **before** the first deployment
✅ Traces, logs, and metrics are **built into** the application architecture
✅ Configuration is **declarative** via environment variables
✅ GenAI-specific semantics follow **emerging standards**

::alert[**Philosophy**: In production systems, observability should be non-negotiable infrastructure, just like logging and error handling. This workshop shows how to build it in from the start.]{type="info"}

## Step 1: Explore the Existing Instrumentation

The ai-workshop application already has complete OpenTelemetry instrumentation. Let's examine how it works.

1. **Navigate to the server directory**:
   ```bash
   cd /workshop/ai-workshop/server
   ls -la
   ```

   Key files:
   - `instrumentation.js` - Entry point for tracing
   - `config/tracing.js` - OpenTelemetry SDK configuration
   - `utils/llmTracing.js` - Custom LLM tracing utilities
   - `index.js` - Server entry point (imports instrumentation FIRST)

2. **Examine the instrumentation entry point**:
   ```bash
   cat instrumentation.js
   ```

   ```javascript
   /**
    * OpenTelemetry Instrumentation Entry Point
    *
    * This file MUST be imported before any other application code
    * to ensure proper auto-instrumentation of libraries.
    */
   import { initializeTracing } from './config/tracing.js';

   // Initialize tracing immediately
   initializeTracing();
   ```

   **Key Insight**: Instrumentation is initialized **before** any other imports. This ensures auto-instrumentation captures all operations.

3. **Best Practice - High-Cardinality Attributes**:

   When instrumenting your application, Honeycomb excels at handling **high-cardinality data**—attributes with many unique values that traditional monitoring tools struggle with. The application includes attributes like:

   - `user.id` or `session.id` - Unique per user/session
   - `request.id` - Unique per request
   - `gen_ai.request.model` - Specific model version used
   - `deployment.environment` - Environment identifier

   ::alert[**Honeycomb Advantage**: Unlike traditional metrics systems that require pre-aggregation, Honeycomb stores raw event data with all high-cardinality attributes intact. This allows you to ask questions like "Show me all requests from user X where token usage exceeded Y" without pre-defining these queries.]{type="success"}

4. **Review the tracing configuration**:
   ```bash
   cat config/tracing.js | head -60
   ```

   This file configures:
   - **OTLP Exporters** for traces and logs
   - **Resource attributes** (service name, version, environment)
   - **Auto-instrumentations** for Express, HTTP, AWS SDK
   - **Winston instrumentation** for log correlation
   - **Honeycomb-specific configuration**

5. **Examine custom LLM tracing utilities**:
   ```bash
   cat utils/llmTracing.js | head -95
   ```

   The `traceLLMCall()` function wraps Bedrock API calls with:
   - **GenAI semantic conventions v1.0**: `gen_ai.system`, `gen_ai.operation.name`, `gen_ai.request.model`
   - **Token usage tracking**: `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`
   - **Error handling**: Proper span status, exception recording, and `error.type` attribute
   - **Response metadata**: `gen_ai.response.id`, `gen_ai.response.finish_reasons`

::alert[**Production Pattern**: Custom instrumentation captures business-specific metrics (token usage, model performance) that auto-instrumentation can't infer. This is critical for cost monitoring and SLO tracking.]{type="success"}

## Step 2: Understand Auto-Instrumentation

The application uses `getNodeAutoInstrumentations()` to automatically instrument popular libraries:

**What's instrumented automatically:**
- ✅ **Express.js**: HTTP request/response spans with route information
- ✅ **HTTP/HTTPS**: Outbound HTTP client calls (to Bedrock, OpenSearch)
- ✅ **AWS SDK**: All AWS service calls (Bedrock InvokeModel, OpenSearch queries)
- ✅ **Winston**: Log correlation with trace and span IDs

**Example trace structure** you'll see:
```
POST /api/chat (Express auto-instrumentation)
├─ gen_ai.bedrock.chat (Custom GenAI instrumentation)
│  └─ AWS Bedrock InvokeModel (AWS SDK auto-instrumentation)
├─ db.vector.search (Custom instrumentation - future enhancement)
│  └─ HTTPS POST OpenSearch (HTTP auto-instrumentation)
└─ Response
```

Each span automatically includes:
- **Timing**: Duration, start/end timestamps
- **Context**: Trace ID, span ID, parent span ID
- **Attributes**: HTTP method, status code, URL, etc.
- **Resource**: Service name, version, deployment environment

## Step 3: Verify Honeycomb Configuration

The Pulumi infrastructure already configured the ECS task with Honeycomb environment variables. Let's verify:

1. **Check the ECS task definition**:
   ```bash
   cd /workshop/ai-workshop/pulumi
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws ecs describe-task-definition \
     --task-definition $(pulumi stack output ecsTaskDefinitionArn | cut -d'/' -f2) \
     --query 'taskDefinition.containerDefinitions[0].environment[?name==`OTEL_SERVICE_NAME` || name==`OTEL_EXPORTER_OTLP_ENDPOINT` || name==`HONEYCOMB_DATASET`]'
   ```

   Expected output:
   ```json
   [
       {
           "name": "HONEYCOMB_DATASET",
           "value": "otel-ai-chatbot-dev"
       },
       {
           "name": "OTEL_EXPORTER_OTLP_ENDPOINT",
           "value": "https://api.honeycomb.io"
       },
       {
           "name": "OTEL_SERVICE_NAME",
           "value": "otel-ai-chatbot-backend"
       }
   ]
   ```

2. **Verify secrets are configured**:
   ```bash
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws ecs describe-task-definition \
     --task-definition $(pulumi stack output ecsTaskDefinitionArn | cut -d'/' -f2) \
     --query 'taskDefinition.containerDefinitions[0].secrets[?name==`HONEYCOMB_API_KEY` || name==`OTEL_EXPORTER_OTLP_HEADERS`]'
   ```

   Expected output:
   ```json
   [
       {
           "name": "HONEYCOMB_API_KEY",
           "valueFrom": "arn:aws:secretsmanager:...secret:HONEYCOMB_API_KEY::"
       },
       {
           "name": "OTEL_EXPORTER_OTLP_HEADERS",
           "valueFrom": "arn:aws:secretsmanager:...secret:OTEL_EXPORTER_OTLP_HEADERS::"
       }
   ]
   ```

::alert[**Configuration via Environment**: OpenTelemetry's SDK reads configuration from environment variables, making it cloud-native and easy to configure without code changes.]{type="info"}

## Step 4: Check Application Logs for Tracing Initialization

1. **View recent CloudWatch logs**:
   ```bash
   cd /workshop/ai-workshop/pulumi
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws logs tail \
     /aws/ecs/otel-ai-chatbot-logs \
     --since 10m \
     --filter-pattern "OpenTelemetry"
   ```

   Look for these log lines:
   ```
   [OpenTelemetry] ✨ Tracing and logging initialized
   [OpenTelemetry] 📊 Service: otel-ai-chatbot-backend
   [OpenTelemetry] 🌍 Environment: development
   [OpenTelemetry] 🔗 Endpoint: https://api.honeycomb.io
   [OpenTelemetry] 📝 Logs will be sent to both CloudWatch and Honeycomb
   ```

   If you see these logs, OpenTelemetry is successfully initialized! ✅

2. **If logs don't show initialization**, check for errors:
   ```bash
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws logs tail \
     /aws/ecs/otel-ai-chatbot-logs \
     --since 10m \
     --filter-pattern "error"
   ```

## Step 5: Generate Traffic to the Application

Now let's generate some requests to create traces.

1. **Get the application URL**:
   ```bash
   cd /workshop/ai-workshop/pulumi
   ALB_URL=$(pulumi stack output albUrl)
   echo "Application URL: $ALB_URL"
   ```

2. **Send a few chat requests**:
   ```bash
   for i in {1..3}; do
     echo "Request $i:"
     curl -X POST "${ALB_URL}/api/chat" \
       -H "Content-Type: application/json" \
       -d '{"message": "How do I instrument Express.js with OpenTelemetry?"}' \
       -w "\nHTTP Status: %{http_code}, Time: %{time_total}s\n\n"
     sleep 2
   done
   ```

   Expected output:
   ```
   Request 1:
   {"success":true,"response":"To instrument Express.js...","sources":[...]}
   HTTP Status: 200, Time: 2.341s

   Request 2:
   {"success":true,"response":"To instrument Express.js...","sources":[...]}
   HTTP Status: 200, Time: 1.876s
   ```

3. **Check health endpoint** (note: this is excluded from tracing):
   ```bash
   curl "${ALB_URL}/api/health"
   ```

   Expected:
   ```json
   {
     "status": "healthy",
     "timestamp": "2024-01-15T10:30:45.123Z",
     "services": {
       "llm": "bedrock",
       "vectorStore": "opensearch"
     }
   }
   ```

::alert[**Health Check Exclusion**: The `/api/health` endpoint is intentionally excluded from tracing (see `config/tracing.js:79-82`) to avoid noisy telemetry from load balancer health checks.]{type="info"}

## Step 6: Verify Traces in Honeycomb

1. **Login to Honeycomb**: https://ui.honeycomb.io

2. **Select your dataset**: `otel-ai-chatbot-dev` (or `otel-ai-chatbot-ws` depending on your stack)

3. **View Recent Traces**:
   - You should see traces appearing in real-time
   - Each trace represents one chat request

4. **Click on a trace to examine it**:

   You'll see the trace waterfall showing:
   ```
   POST /api/chat (root span)
   ├─ llm.bedrock.call (~1.8s)
   │  └─ AWS Bedrock InvokeModel (~1.7s)
   ├─ db.opensearch.query (~0.3s)
   │  └─ HTTPS POST OpenSearch (~0.2s)
   └─ serialization (~0.05s)
   ```

5. **Examine span attributes**:

   Click on the `gen_ai.bedrock.chat` span to see attributes:
   - `gen_ai.system` = "aws.bedrock"
   - `gen_ai.operation.name` = "chat"
   - `gen_ai.request.model` = "anthropic.claude-3-5-sonnet-20240620-v1:0"
   - `gen_ai.usage.input_tokens` = 652
   - `gen_ai.usage.output_tokens` = 234
   - `gen_ai.response.finish_reasons` = ["stop"]
   - `gen_ai.response.id` = "msg_01ABC..."
   - `server.address` = "bedrock-runtime.us-east-1.amazonaws.com"

::alert[**Success!** You're now seeing production-grade observability data. The application was instrumented from day one, and you only had to configure where to send the data.]{type="success"}

## Step 7: Understand the GenAI Semantic Conventions

The LLM tracing follows OpenTelemetry's **standardized semantic conventions for GenAI** workloads. These conventions were recently finalized as part of OpenTelemetry's official specifications, representing a major milestone for standardizing AI observability across the industry.

| Attribute | Description | Example |
|-----------|-------------|---------|
| `gen_ai.system` | The GenAI system/provider | "bedrock", "openai", "anthropic" |
| `gen_ai.request.model` | Model identifier | "anthropic.claude-3-5-sonnet-20240620-v1:0" |
| `gen_ai.operation.name` | Type of GenAI operation | "completion", "embedding", "chat" |
| `gen_ai.usage.input_tokens` | Input tokens consumed | 652 |
| `gen_ai.usage.output_tokens` | Output tokens generated | 234 |
| `gen_ai.response.finish_reasons` | Completion reason | "stop", "length", "error" |
| `gen_ai.prompt.0.content` | First prompt content (sampling) | "You are a helpful assistant..." |
| `gen_ai.response.id` | Unique response identifier | "msg_01ABC..." |
| `error.type` | Error type if failed | "RateLimitError", "InvalidRequest" |

**Why these attributes matter:**
- **Cost tracking**: Token usage directly correlates to API costs ($3-15 per million tokens)
- **Performance monitoring**: Duration helps identify slow models or API issues
- **Error analysis**: Distinguish between rate limits, timeouts, and invalid requests
- **Model comparison**: Compare performance across different models and versions
- **Prompt engineering**: Analyze which prompts lead to better outcomes (when sampled)
- **User attribution**: Track which users/teams consume the most tokens

::alert[**OpenTelemetry Standard**: As of 2025, GenAI semantic conventions are now part of the official OpenTelemetry specification. This ensures consistent instrumentation across all observability vendors. See https://opentelemetry.io/docs/specs/semconv/gen-ai/ for complete details.]{type="success"}

### Best Practice: Capturing the Right Context

When instrumenting GenAI applications, Honeycomb recommends capturing:

1. **All errors** - Not just LLM API failures, but also:
   - Invalid or malformed responses that cause downstream errors
   - Timeout errors from slow responses
   - Rate limiting and quota exceeded errors

2. **User/team identifiers** - High-cardinality attributes like:
   - `user.id` - Track per-user behavior and costs
   - `team.id` - Analyze usage by team or organization
   - `session.id` - Correlate multiple requests in a conversation

3. **The actual prompt** (with sampling) - For debugging and optimization:
   - Use `gen_ai.prompt.0.content` to capture the system prompt
   - **Privacy consideration**: Sample at ~1% in production to protect sensitive user data
   - Always capture prompts for errors (100% sampling on failures) to aid debugging
   - Consider redacting PII from prompts before sending to observability platforms

4. **RAG context** - If using retrieval-augmented generation:
   - `rag.documents_retrieved` - Number of documents fetched
   - `rag.documents_used` - Number actually included in context
   - `rag.retrieval_latency_ms` - Time spent on vector search

5. **Function/tool calls** - For agentic workflows:
   - `gen_ai.tools_count` - Number of tools available
   - `gen_ai.tool_calls` - Which tools were invoked
   - Each tool call as a child span with its own attributes

::alert[**Privacy vs. Visibility**: While Honeycomb doesn't charge extra for high-cardinality attributes, consider sampling sensitive data like full prompts/responses primarily for **privacy protection**. Capture 100% of metadata (tokens, model, latency, user IDs) but sample full prompt/response content at 1-10% depending on your privacy requirements. Always implement PII redaction for production workloads.]{type="info"}

## Step 8: Explore Log Correlation

One powerful feature of OpenTelemetry is **log-trace correlation**. Winston logs are automatically correlated with traces.

1. **View logs with trace context**:
   ```bash
   cd /workshop/ai-workshop/pulumi
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws logs tail \
     /aws/ecs/otel-ai-chatbot-logs \
     --since 5m \
     --filter-pattern "POST /api/chat"
   ```

   You'll see logs like:
   ```json
   {
     "message": "Incoming request: POST /api/chat",
     "level": "info",
     "trace_id": "7f8c9d2e1a3b4c5d6e7f8g9h0i1j2k3l",
     "span_id": "a1b2c3d4e5f6g7h8",
     "timestamp": "2024-01-15T10:30:45.123Z"
   }
   ```

2. **In Honeycomb**, click on a log event and you'll see:
   - **Trace ID**: Links directly to the associated trace
   - **Span ID**: Links to the specific span where the log occurred
   - **Service context**: Automatic enrichment with service name, version, environment

This correlation allows you to:
- Navigate from log → trace
- Navigate from trace → logs
- Understand the full context of any event

## Step 9: Best Practice - Deployment Markers (Optional)

Honeycomb supports **markers** to annotate your telemetry data with deployment events. This helps correlate performance changes with code deployments.

To create a marker when deploying:

```bash
# After a successful deployment
HONEYCOMB_API_KEY="your-api-key"
DATASET="otel-ai-chatbot-dev"

curl https://api.honeycomb.io/1/markers/$DATASET \
  -X POST \
  -H "X-Honeycomb-Team: $HONEYCOMB_API_KEY" \
  -d '{
    "message": "Deployed v1.2.3 - Improved LLM instrumentation",
    "type": "deploy",
    "url": "https://github.com/your-repo/commit/abc123"
  }'
```

Markers appear as vertical lines in your Honeycomb graphs, making it easy to see if latency increased or errors spiked after a deployment.

::alert[**CI/CD Integration**: Add marker creation to your CI/CD pipeline so every deployment is automatically annotated in Honeycomb. This is invaluable for incident response and performance regression analysis.]{type="info"}

## Module Summary

Congratulations! You've successfully:

✅ Explored the existing OpenTelemetry instrumentation in the application
✅ Understood auto-instrumentation for Express, HTTP, and AWS SDK
✅ Reviewed custom LLM tracing with GenAI semantic conventions
✅ Learned about high-cardinality attributes and why they matter
✅ Verified Honeycomb configuration in the ECS task
✅ Generated traffic and confirmed traces are flowing to Honeycomb
✅ Examined trace structure and GenAI-specific attributes
✅ Understood log-trace correlation
✅ Learned best practices for sampling and capturing context

## Key Takeaways

### 1. Observability-Driven Development Culture

Just like you wouldn't deploy without logging or error handling, you shouldn't deploy without observability. Build it in from day one. At Honeycomb, engineers add telemetry as a **core part** of every feature and bug fix, creating a culture where observability is everyone's responsibility.

### 2. High-Cardinality is a Feature, Not a Bug

Traditional monitoring tools force you to aggregate away high-cardinality data (like user IDs, request IDs, model versions). Honeycomb **embraces** high-cardinality, allowing you to ask questions like "Show me all requests from user X where model Y exceeded Z tokens"—without pre-defining these queries.

### 3. Auto-Instrumentation Does the Heavy Lifting

OpenTelemetry's auto-instrumentation captures 80% of telemetry with zero code changes. Custom instrumentation fills the remaining 20% for business-specific metrics like token usage, RAG performance, and agentic workflows.

### 4. Configuration is Declarative

Environment variables control where telemetry goes, making it easy to send data to different backends without code changes (Honeycomb today, Jaeger tomorrow). This is the OpenTelemetry promise: **vendor-neutral instrumentation**.

### 5. GenAI Workloads Need Specialized Observability

Token usage, model selection, and prompt engineering directly impact cost and performance. The OpenTelemetry GenAI semantic conventions (now standardized) ensure consistent instrumentation across providers, making it easy to compare Bedrock vs OpenAI vs Anthropic direct.

### 6. Balance Privacy and Visibility with Sampling

Capture 100% of structured metadata (tokens, model, latency, user ID), but sample sensitive unstructured data like full prompts/responses at 1-10% primarily for **privacy protection**. Always capture 100% on errors for debugging, ensuring PII is redacted first.

### 7. Context Propagation is Automatic

OpenTelemetry automatically propagates trace context across service boundaries (HTTP calls, async operations, AWS SDK calls), giving you end-to-end visibility from API gateway → application → Bedrock → OpenSearch without manual plumbing.

## What's Next?

In **Module 3**, you'll use Honeycomb to analyze the telemetry data you're now collecting, identify performance bottlenecks, and discover resource constraints in the infrastructure.

---

## Additional Resources

- [OpenTelemetry Node.js Documentation](https://opentelemetry.io/docs/instrumentation/js/getting-started/nodejs/)
- [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- [Honeycomb OpenTelemetry Setup Guide](https://docs.honeycomb.io/getting-data-in/opentelemetry/)
- [AWS Distro for OpenTelemetry](https://aws-otel.github.io/)
