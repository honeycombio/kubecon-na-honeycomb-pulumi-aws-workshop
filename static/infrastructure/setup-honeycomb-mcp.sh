#!/usr/bin/env bash
# Set up DevOps Agent operator app and register Honeycomb MCP server.
#
# This script:
# 1. Enables the operator app (web UI) using IAM auth flow
# 2. Registers the Honeycomb MCP server via OAuth authorization discovery
# 3. Associates the Honeycomb MCP server with the Agent Space
#
# Usage:
#   ./setup-honeycomb-mcp.sh <CFN_STACK_NAME>
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
  echo "Usage: $0 <CFN_STACK_NAME>"
  echo ""
  echo "  CFN_STACK_NAME   Name of the deployed devops_agent.yaml CloudFormation stack"
  exit 1
fi

CFN_STACK_NAME="$1"

# Verify the devopsagent service model is installed
if ! aws devopsagent help >/dev/null 2>&1; then
  echo "ERROR: The devopsagent CLI service model is not installed."
  echo ""
  echo "Install it with:"
  echo "  curl -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json"
  echo "  aws configure add-model --service-model file:///tmp/devopsagent.json --service-name devopsagent"
  exit 1
fi

echo "==> Reading stack outputs from $CFN_STACK_NAME..."

STACK_OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$CFN_STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs' --output json 2>&1)

AGENT_SPACE_ID=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey == "AgentSpaceId") | .OutputValue')
OPERATOR_ROLE_ARN=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey == "OperatorAppRoleArn") | .OutputValue')

if [[ -z "$AGENT_SPACE_ID" ]]; then
  echo "ERROR: Could not find AgentSpaceId in stack outputs."
  exit 1
fi
if [[ -z "$OPERATOR_ROLE_ARN" ]]; then
  echo "ERROR: Could not find OperatorAppRoleArn in stack outputs."
  exit 1
fi

echo "    Agent Space ID:     $AGENT_SPACE_ID"
echo "    Operator Role ARN:  $OPERATOR_ROLE_ARN"

# --- Step 1: Enable operator app ---

echo ""
echo "==> Enabling operator app (IAM auth flow)..."

ENABLE_OUTPUT=""
if ! ENABLE_OUTPUT=$(aws devopsagent enable-operator-app \
    --agent-space-id "$AGENT_SPACE_ID" \
    --auth-flow iam \
    --operator-app-role-arn "$OPERATOR_ROLE_ARN" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" 2>&1); then
  # Already enabled is not an error
  if echo "$ENABLE_OUTPUT" | grep -q "already enabled\|AlreadyExists\|ConflictException"; then
    echo "    Operator app already enabled, skipping."
  else
    echo "ERROR: Failed to enable operator app."
    echo "$ENABLE_OUTPUT"
    exit 1
  fi
else
  echo "    Operator app enabled."
fi

# --- Step 2: Register Honeycomb MCP server ---

# Tools to allowlist (read-only operations only)
TOOLS_JSON='[
  "run_query", "run_bubbleup", "get_trace",
  "get_dataset", "get_dataset_columns", "find_columns",
  "find_queries", "get_query_results", "get_triggers",
  "get_workspace_context", "get_environment",
  "list_boards"
]'

echo ""
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

# --- Step 3: Associate Honeycomb MCP with Agent Space ---

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
echo "    Agent Space ID: $AGENT_SPACE_ID"
echo "    Service ID:     $SERVICE_ID"
if [[ -n "$ASSOCIATION_ID" ]]; then
  echo "    Association ID: $ASSOCIATION_ID"
fi
echo ""
echo "Open the DevOps Agent console:"
echo "  https://us-east-1.console.aws.amazon.com/devopsagent/home?region=us-east-1#/spaces/$AGENT_SPACE_ID"
echo ""
echo "Or verify via CLI:"
echo "  aws devopsagent list-associations --agent-space-id $AGENT_SPACE_ID --region $REGION --endpoint-url $ENDPOINT"
