---
title: "Step 4: Advanced - Use MCP to Analyze Instrumentation Quality (Optional)"
weight: 64
---

One powerful capability of Honeycomb MCP is analyzing instrumentation patterns across your services. Let's use Claude Code to examine our instrumentation quality.

**Ask Claude Code to analyze instrumentation:**

```
Query Honeycomb to show me what attributes are being captured on the gen_ai.bedrock.chat spans.
Are we following OpenTelemetry GenAI semantic conventions v1.0?
```

Claude Code will:
1. Query for recent `gen_ai.bedrock.chat` spans
2. List all attributes being captured
3. Compare against OpenTelemetry v1.0 specifications
4. Identify any missing recommended attributes

**Expected insights:**
```
✅ Required attributes present:
   - gen_ai.system: "aws.bedrock"
   - gen_ai.operation.name: "chat"
   - gen_ai.request.model: "anthropic.claude-3-5-sonnet-20240620-v1:0"

✅ Recommended attributes present:
   - gen_ai.usage.input_tokens
   - gen_ai.usage.output_tokens
   - gen_ai.response.finish_reasons
   - gen_ai.response.id

⚠️  Optional attributes not captured:
   - gen_ai.prompt.*.content (intentionally omitted for privacy)
   - gen_ai.request.temperature
   - gen_ai.request.max_tokens
```

**Follow-up prompt to improve instrumentation:**

```
Based on the Honeycomb data, can you suggest improvements to our llmTracing.js
to add the missing recommended attributes like temperature and max_tokens?
```

Claude Code will:
1. Review current `llmTracing.js` implementation
2. Identify where to add missing attributes
3. Propose code changes with proper v1.0 naming
4. Ensure changes follow best practices

::alert[**MCP Superpower**: This workflow demonstrates using observability data to drive instrumentation improvements. The AI agent learns from what's actually being captured in production and suggests enhancements based on standards and patterns it discovers.]{type="success"}