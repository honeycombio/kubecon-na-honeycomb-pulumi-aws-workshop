---
title: "Step 1: Generate Application Load"
weight: 501
---

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