#!/usr/bin/env bash
# Register the Honeycomb MCP server with AWS DevOps Agent and associate it
# with an Agent Space.
#
# The Honeycomb MCP server uses OAuth 2.0 authorization code flow. This script
# registers the MCP server using authorization discovery (auto-discovers OAuth
# endpoints from Honeycomb's .well-known metadata), then opens a browser for
# you to authorize the connection. After authorization, it associates the
# registered service with the Agent Space.
#
# Usage:
#   ./setup-honeycomb-mcp.sh <AGENT_SPACE_ID>
#
# Prerequisites:
#   - AWS CLI v2 configured with credentials for the target account
#   - The devopsagent CLI service model installed:
#       curl -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json
#       aws configure add-model --service-model file:///tmp/devopsagent.json --service-name devopsagent
#   - jq installed
#   - The devops_agent.yaml CloudFormation stack already deployed

set -euo pipefail

REGION="us-east-1"
ENDPOINT="https://api.prod.cp.aidevops.us-east-1.api.aws"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <AGENT_SPACE_ID>"
  echo ""
  echo "  AGENT_SPACE_ID   From CloudFormation output AgentSpaceId"
  exit 1
fi

AGENT_SPACE_ID="$1"

# Verify the devopsagent service model is installed
if ! aws devopsagent help >/dev/null 2>&1; then
  echo "ERROR: The devopsagent CLI service model is not installed."
  echo ""
  echo "Install it with:"
  echo "  curl -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json"
  echo "  aws configure add-model --service-model file:///tmp/devopsagent.json --service-name devopsagent"
  exit 1
fi

# Tools to allowlist (read-only operations only)
TOOLS_JSON='[
  "run_query", "run_bubbleup", "get_trace",
  "get_dataset", "get_dataset_columns", "find_columns",
  "find_queries", "get_query_results", "get_triggers",
  "get_workspace_context", "get_environment",
  "list_boards"
]'

echo "==> Registering Honeycomb MCP server (OAuth authorization discovery)..."

REGISTER_PAYLOAD='{
  "mcpserver": {
    "name": "honeycomb",
    "endpoint": "https://mcp.honeycomb.io/mcp",
    "authorizationConfig": {
      "authorizationDiscovery": {
        "returnToEndpoint": "https://us-east-1.console.aws.amazon.com/devopsagent"
      }
    }
  }
}'

REGISTER_OUTPUT=""
if ! REGISTER_OUTPUT=$(aws devopsagent register-service \
    --service mcpserver \
    --service-details "$REGISTER_PAYLOAD" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" 2>&1); then
  echo "ERROR: Failed to register Honeycomb MCP server."
  echo "$REGISTER_OUTPUT"
  exit 1
fi

# Extract the OAuth authorization URL from the response
AUTH_URL=$(echo "$REGISTER_OUTPUT" | jq -r '.additionalStep.oauth.authorizationUrl // empty')
if [[ -z "$AUTH_URL" ]]; then
  echo "ERROR: No OAuth authorization URL in register-service response:"
  echo "$REGISTER_OUTPUT"
  exit 1
fi

echo ""
echo "==> Opening browser for Honeycomb OAuth authorization..."
echo "    If the browser does not open, visit this URL manually:"
echo ""
echo "    $AUTH_URL"
echo ""

# Try to open the browser (macOS: open, Linux: xdg-open)
if command -v open >/dev/null 2>&1; then
  open "$AUTH_URL"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$AUTH_URL"
fi

echo "    Authorize the connection in Honeycomb, then press Enter to continue..."
read -r

echo "==> Looking up Honeycomb service ID..."

SERVICE_ID=""
SERVICE_ID=$(aws devopsagent list-services \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" 2>&1 \
  | jq -r '.services[] | select(.serviceType == "mcpserver" and .additionalServiceDetails.mcpserver.name == "honeycomb") | .serviceId')

if [[ -z "$SERVICE_ID" ]]; then
  echo "ERROR: Could not find registered Honeycomb MCP service."
  echo "Did you complete the OAuth authorization in the browser?"
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
if ! ASSOCIATE_OUTPUT=$(aws devopsagent associate-service \
    --agent-space-id "$AGENT_SPACE_ID" \
    --service-id "$SERVICE_ID" \
    --configuration "$ASSOCIATE_PAYLOAD" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" 2>&1); then
  echo "ERROR: Failed to associate Honeycomb MCP server."
  echo "$ASSOCIATE_OUTPUT"
  exit 1
fi

ASSOCIATION_ID=$(echo "$ASSOCIATE_OUTPUT" | jq -r '.association.associationId // empty')

echo ""
echo "==> Done!"
echo "    Service ID:     $SERVICE_ID"
if [[ -n "$ASSOCIATION_ID" ]]; then
  echo "    Association ID: $ASSOCIATION_ID"
fi
echo ""
echo "Verify in the console:"
echo "  https://us-east-1.console.aws.amazon.com/devopsagent/"
echo ""
echo "Or via CLI:"
echo "  aws devopsagent list-associations --agent-space-id $AGENT_SPACE_ID --region $REGION --endpoint-url $ENDPOINT"
