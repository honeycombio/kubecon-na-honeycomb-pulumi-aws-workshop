#!/usr/bin/env bash
# Register the Honeycomb MCP server with AWS DevOps Agent and associate it
# with an Agent Space.
#
# Usage:
#   ./setup-honeycomb-mcp.sh <AGENT_SPACE_ID> <HONEYCOMB_KEY_ID> <HONEYCOMB_KEY_SECRET>
#
# Prerequisites:
#   - AWS CLI v2 configured with credentials for the target account
#   - jq installed
#   - The devops_agent.yaml CloudFormation stack already deployed

set -euo pipefail

REGION="us-east-1"
# Custom endpoint for DevOps Agent API (fallback if CLI service model not registered)
CUSTOM_ENDPOINT="https://api.prod.cp.aidevops.us-east-1.api.aws"

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <AGENT_SPACE_ID> <HONEYCOMB_KEY_ID> <HONEYCOMB_KEY_SECRET>"
  echo ""
  echo "  AGENT_SPACE_ID         From CloudFormation output AgentSpaceId"
  echo "  HONEYCOMB_KEY_ID       Honeycomb Management Key ID"
  echo "  HONEYCOMB_KEY_SECRET   Honeycomb Management Key Secret"
  exit 1
fi

AGENT_SPACE_ID="$1"
HONEYCOMB_KEY_ID="$2"
HONEYCOMB_KEY_SECRET="$3"

# Tools to allowlist (read-only operations only)
TOOLS_JSON='[
  "run_query", "run_bubbleup", "get_trace",
  "get_dataset", "get_dataset_columns", "find_columns",
  "find_queries", "get_query_results",
  "get_service_map", "get_slos", "get_triggers",
  "get_workspace_context", "get_environment",
  "list_boards"
]'

echo "==> Registering Honeycomb MCP server..."

REGISTER_PAYLOAD=$(cat <<EOF
{
  "mcpserver": {
    "name": "honeycomb",
    "endpoint": "https://mcp.honeycomb.io/mcp",
    "authorizationConfig": {
      "apiKey": {
        "apiKeyName": "Authorization",
        "apiKey": "Bearer ${HONEYCOMB_KEY_ID}:${HONEYCOMB_KEY_SECRET}"
      }
    }
  }
}
EOF
)

# Try standard endpoint first, fall back to custom endpoint
REGISTER_OUTPUT=""
if REGISTER_OUTPUT=$(aws devopsagent register-service \
    --service mcpserver \
    --service-details "$REGISTER_PAYLOAD" \
    --region "$REGION" 2>&1); then
  echo "    Registered via standard AWS CLI endpoint."
elif REGISTER_OUTPUT=$(aws devopsagent register-service \
    --service mcpserver \
    --service-details "$REGISTER_PAYLOAD" \
    --region "$REGION" \
    --endpoint-url "$CUSTOM_ENDPOINT" 2>&1); then
  echo "    Registered via custom endpoint ($CUSTOM_ENDPOINT)."
else
  echo "ERROR: Failed to register Honeycomb MCP server."
  echo "$REGISTER_OUTPUT"
  exit 1
fi

SERVICE_ID=$(echo "$REGISTER_OUTPUT" | jq -r '.serviceId // .ServiceId // empty')
if [[ -z "$SERVICE_ID" ]]; then
  echo "ERROR: Could not extract serviceId from register-service response:"
  echo "$REGISTER_OUTPUT"
  exit 1
fi

echo "    Service ID: $SERVICE_ID"

echo "==> Associating Honeycomb MCP server with Agent Space $AGENT_SPACE_ID..."

ASSOCIATE_PAYLOAD=$(cat <<EOF
{
  "mcpserver": {
    "name": "honeycomb",
    "endpoint": "https://mcp.honeycomb.io/mcp",
    "tools": $TOOLS_JSON
  }
}
EOF
)

ASSOCIATE_OUTPUT=""
if ASSOCIATE_OUTPUT=$(aws devopsagent associate-service \
    --agent-space-id "$AGENT_SPACE_ID" \
    --service-id "$SERVICE_ID" \
    --configuration "$ASSOCIATE_PAYLOAD" \
    --region "$REGION" 2>&1); then
  echo "    Associated via standard AWS CLI endpoint."
elif ASSOCIATE_OUTPUT=$(aws devopsagent associate-service \
    --agent-space-id "$AGENT_SPACE_ID" \
    --service-id "$SERVICE_ID" \
    --configuration "$ASSOCIATE_PAYLOAD" \
    --region "$REGION" \
    --endpoint-url "$CUSTOM_ENDPOINT" 2>&1); then
  echo "    Associated via custom endpoint ($CUSTOM_ENDPOINT)."
else
  echo "ERROR: Failed to associate Honeycomb MCP server."
  echo "$ASSOCIATE_OUTPUT"
  exit 1
fi

ASSOCIATION_ID=$(echo "$ASSOCIATE_OUTPUT" | jq -r '.associationId // .AssociationId // empty')

echo ""
echo "==> Done!"
echo "    Service ID:     $SERVICE_ID"
if [[ -n "$ASSOCIATION_ID" ]]; then
  echo "    Association ID: $ASSOCIATION_ID"
fi
echo ""
echo "Verify in the console:"
echo "  https://console.aws.amazon.com/devopsagent/"
echo ""
echo "Or via CLI:"
echo "  aws devopsagent list-associations --agent-space-id $AGENT_SPACE_ID --region $REGION"
