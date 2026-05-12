---
title: "Step 1: Setup IDE with MCP servers"
weight: 61
---

Kiro CLI should be pre-installed in your VS Code Server environment. If you prefer to use a different AI IDE or CLI (such as Cursor, Windsurf, or Zed), you can follow their respective MCP configuration guides.

1. Verify Kiro CLI is installed:
   ```bash
   kiro-cli --version
   ```

2. Login to Kiro CLI. **Make sure to add** *--use-device-flow* flag. Select **Use for Free with Builder ID** option.

   ```bash
   kiro-cli-chat login --use-device-flow
   ```

   Once prompted, follow the authentication link, login or sign up for a free account. Confirm the authentication code, and confirm **Allow access** for Kiro CLI.

3. Verify MCP support is enabled:
   ```bash
   kiro-cli-chat mcp list
   ```

   This will show any currently configured MCP servers. Initially, it is empty.

::alert[**AI Tool Choice**: This workshop uses Kiro CLI for examples, but the MCP protocol is standardized. You can use any MCP-compatible AI assistant (Kiro, Claude Code, Cursor, Windsurf, etc.) with the same MCP servers.]{type="info"}

## Step 2: Add Honeycomb MCP Server

The Honeycomb MCP server lets your AI assistant query your observability data directly. As of 2026, the Honeycomb MCP server uses **OAuth 2.0 authorization discovery** — no API key or bearer header is required in the MCP configuration itself.

Add the Honeycomb MCP server (no API key needed in the command):

   ```bash
   kiro-cli-chat mcp add --name honeycomb --command npx --args "-y,mcp-remote,https://mcp.honeycomb.io/mcp"
   ```

(Use `https://mcp.eu1.honeycomb.io/mcp` if your Honeycomb tenant lives in the EU region.)

On first use, `mcp-remote` will open your browser to the Honeycomb OAuth consent screen. Log in with your Honeycomb account and authorize the MCP client — tokens are cached locally afterwards.

::alert[**Why OAuth?**: OAuth replaces the older "Bearer `<KEY_ID>:<SECRET_KEY>`" header flow. You no longer need to create a Management API Key just to use the MCP server, and access is automatically scoped to whatever your Honeycomb user can already see. Headless agents that cannot prompt a browser can still fall back to the API-key header method — see the [Honeycomb MCP configuration guide](https://docs.honeycomb.io/integrations/mcp/configuration-guide/) for that workflow.]{type="info"}

::alert[**Fresh tool listing & Canvas Agent**: After (re-)authenticating, the MCP server returns a fresh listing of the tools your tenant is entitled to. If your team is feature-flagged into the Honeycomb **Canvas Agent**, you'll see the new `canvas_agent_invoke` and `canvas_agent_poll_response` tools alongside the standard query tools. The Canvas Agent lets your IDE delegate multi-step Honeycomb investigations to a server-side agent rather than orchestrating each tool call from the client.]{type="success"}

## Step 3: Add Pulumi MCP Server

The Pulumi MCP server allows to inspect infrastructure state and invoke Pulumi Neo for code generation.

Add the Pulumi MCP server:
   ```bash
   kiro-cli-chat mcp add --name pulumi --command npx --args "mcp-remote,https://mcp.ai.pulumi.com/mcp,--header,Authorization: Bearer <PULUMI_TOKEN>,--header,X-Pulumi-Org:<PULUMI_ORG>"
   ```

::alert[**Documentation**: For detailed Pulumi MCP configuration and capabilities, see: https://www.pulumi.com/docs/iac/using-pulumi/mcp-server/]{type="info"}

## Verify MCP servers configuration and authenticate

1. Verify both MCP servers are configured:
   ```bash
   kiro-cli-chat mcp list
   ```

2. Start Kiro CLI chat to initiate authentication:

   ```bash
   kiro-cli-chat
   ```

3. The first Honeycomb tool call will pop a browser window for OAuth consent. Approve it, then return to the terminal — Kiro should now have a fresh listing of Honeycomb tools (including the Canvas Agent tools if your team is feature-flagged in).

4. Test the connection by asking questions:
   ```
   What Honeycomb datasets are available?
   ```

   ```
   What Pulumi stacks do I have in my organization?
   ```

::alert[**Re-fetching the tool list**: If your team gets feature-flagged into a new Honeycomb capability mid-session, run `kiro-cli-chat mcp restart honeycomb` (or restart your IDE's MCP host). The server returns whatever toolset your account is entitled to *at connection time*, so a reconnect is required to pick up newly enabled tools.]{type="info"}