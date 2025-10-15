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

3. **Review the tracing configuration**:
   ```bash
   cat config/tracing.js | head -60
   ```

   This file configures:
   - **OTLP Exporters** for traces and logs
   - **Resource attributes** (service name, version, environment)
   - **Auto-instrumentations** for Express, HTTP, AWS SDK
   - **Winston instrumentation** for log correlation
   - **Honeycomb-specific configuration**

4. **Examine custom LLM tracing utilities**:
   ```bash
   cat utils/llmTracing.js | head -95
   ```

   The `traceLLMCall()` function wraps Bedrock API calls with:
   - **GenAI semantic conventions**: `llm.provider`, `llm.model`, `llm.request_type`
   - **Token usage tracking**: `llm.usage.prompt_tokens`, `llm.usage.completion_tokens`
   - **Error handling**: Proper span status and exception recording
   - **Duration tracking**: `llm.duration_ms`

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
├─ llm.bedrock.call (Custom LLM instrumentation)
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

   Click on the `llm.bedrock.call` span to see attributes:
   - `llm.provider` = "bedrock"
   - `llm.model` = "anthropic.claude-3-5-sonnet-20240620-v1:0"
   - `llm.request_type` = "completion"
   - `llm.usage.prompt_tokens` = 652
   - `llm.usage.completion_tokens` = 234
   - `llm.usage.total_tokens` = 886
   - `llm.duration_ms` = 1876

::alert[**Success!** You're now seeing production-grade observability data. The application was instrumented from day one, and you only had to configure where to send the data.]{type="success"}

## Step 7: Understand the GenAI Semantic Conventions

The LLM tracing follows OpenTelemetry's **emerging semantic conventions for GenAI** workloads:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `llm.provider` | LLM service provider | "bedrock", "openai", "anthropic" |
| `llm.model` | Model identifier | "anthropic.claude-3-5-sonnet-20240620-v1:0" |
| `llm.request_type` | Type of LLM operation | "completion", "embedding", "chat" |
| `llm.usage.prompt_tokens` | Input tokens consumed | 652 |
| `llm.usage.completion_tokens` | Output tokens generated | 234 |
| `llm.usage.total_tokens` | Total tokens (input + output) | 886 |
| `llm.duration_ms` | API call duration | 1876 |
| `llm.response.success` | Whether call succeeded | true/false |
| `llm.error.type` | Error type if failed | "RateLimitError" |

**Why these attributes matter:**
- **Cost tracking**: Token usage directly correlates to API costs
- **Performance monitoring**: Duration helps identify slow models or API issues
- **Error analysis**: Distinguish between rate limits, timeouts, and other errors
- **Model comparison**: Compare performance across different models

::alert[**Emerging Standards**: OpenTelemetry's GenAI semantic conventions are still evolving. Check https://opentelemetry.io/docs/specs/semconv/gen-ai/ for the latest specifications.]{type="info"}

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

## Module Summary

Congratulations! You've successfully:

✅ Explored the existing OpenTelemetry instrumentation in the application
✅ Understood auto-instrumentation for Express, HTTP, and AWS SDK
✅ Reviewed custom LLM tracing with GenAI semantic conventions
✅ Verified Honeycomb configuration in the ECS task
✅ Generated traffic and confirmed traces are flowing to Honeycomb
✅ Examined trace structure and GenAI-specific attributes
✅ Understood log-trace correlation

## Key Takeaways

### 1. Observability is Infrastructure

Just like you wouldn't deploy without logging or error handling, you shouldn't deploy without observability. Build it in from day one.

### 2. Auto-Instrumentation Does the Heavy Lifting

OpenTelemetry's auto-instrumentation captures 80% of telemetry with zero code changes. Custom instrumentation fills the remaining 20% for business-specific metrics.

### 3. Configuration is Declarative

Environment variables control where telemetry goes, making it easy to send data to different backends without code changes (Honeycomb today, Jaeger tomorrow).

### 4. GenAI Workloads Need Specialized Observability

Token usage, model selection, and prompt engineering directly impact cost and performance. Custom instrumentation captures these critical metrics.

### 5. Context Propagation is Automatic

OpenTelemetry automatically propagates trace context across service boundaries (HTTP calls, async operations, etc.), giving you end-to-end visibility.

## What's Next?

In **Module 3**, you'll use Honeycomb to analyze the telemetry data you're now collecting, identify performance bottlenecks, and discover resource constraints in the infrastructure.

---

## Additional Resources

- [OpenTelemetry Node.js Documentation](https://opentelemetry.io/docs/instrumentation/js/getting-started/nodejs/)
- [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- [Honeycomb OpenTelemetry Setup Guide](https://docs.honeycomb.io/getting-data-in/opentelemetry/)
- [AWS Distro for OpenTelemetry](https://aws-otel.github.io/)
