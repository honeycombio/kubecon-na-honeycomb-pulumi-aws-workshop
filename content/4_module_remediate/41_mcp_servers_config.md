---
title: "Step 1: Setup IDE with MCP servers"
weight: 61
---

Claude Code should be pre-installed in your VS Code Server environment. If you prefer to use a different AI IDE or CLI (such as Cursor, Windsurf, or Zed), you can follow their respective MCP configuration guides.

1. Verify Claude Code CLI is installed:
   ```bash
   claude --version
   ```

   Expected output: `2.x.x (Claude Code)` or similar

2. If not installed, install it by following the instructions at:
   - **Claude Code**: https://claude.ai/download

3. Verify MCP support is enabled:
   ```bash
   claude mcp list
   ```

   This will show any currently configured MCP servers. Initially, you may see:
   ```
   Checking MCP server health...

   (No servers configured yet)
   ```

   Or if you have other MCP servers configured, they will be listed here.

::alert[**AI Tool Choice**: This workshop uses Claude Code for examples, but the MCP protocol is standardized. You can use any MCP-compatible AI assistant (Cursor, Windsurf, Zed, etc.) with the same MCP servers.]{type="info"}

## Step 2: Add Honeycomb MCP Server

The Honeycomb MCP server allows Claude Code to query your observability data directly. We'll use OAuth authentication, which eliminates the need to manage API keys.

1. Add the Honeycomb MCP server to Claude Code:
   ```bash
   claude mcp add honeycomb --transport http https://mcp.honeycomb.io/mcp
   ```

   This command will:
   - Add the Honeycomb MCP server to your Claude Code configuration
   - Prepare OAuth authentication (authentication happens on first use)

2. Authenticate with Honeycomb (OAuth flow):

   When you first use the Honeycomb MCP server, Claude Code will prompt you to authenticate. The OAuth flow will:
   - Open your browser to Honeycomb's authorization page
   - Ask you to grant Claude Code access to your Honeycomb data
   - Redirect back to Claude Code with authentication complete

   **No API keys needed!** OAuth tokens are managed automatically and securely.

3. Verify the Honeycomb MCP server is configured:
   ```bash
   claude mcp list
   ```

   Expected output:
   ```
   Checking MCP server health...

   honeycomb: https://mcp.honeycomb.io/mcp (HTTP) - ✓ Connected
   ```

4. Test the connection by asking Claude Code:
   ```
   What Honeycomb datasets are available?
   ```

   Claude Code will:
   - Trigger the OAuth flow (if not already authenticated)
   - Query your available datasets
   - Display the results

::alert[**OAuth Benefits**: OAuth authentication is more secure than API keys - tokens are short-lived, automatically refreshed, and can be easily revoked. You never need to copy/paste sensitive credentials!]{type="success"}

::alert[**Documentation**: For detailed Honeycomb MCP configuration options, see: https://docs.honeycomb.io/integrations/mcp/configuration-guide/#setting-up-oauth]{type="info"}

## Step 3: Add Pulumi MCP Server

The Pulumi MCP server allows Claude Code to inspect infrastructure state and invoke Pulumi Neo for code generation.

1. Get your Pulumi organization name:
   ```bash
   pulumi whoami
   ```

   Note the organization name displayed.

2. Add the Pulumi MCP server to Claude Code:
   ```bash
   claude mcp add pulumi --transport http https://mcp.ai.pulumi.com/mcp
   ```

   You'll be prompted to authenticate with Pulumi. The MCP server will use your existing Pulumi access token from your login session.

3. Configure the default organization (optional):

   The Pulumi MCP server will automatically detect your organization from your Pulumi login. If you need to specify a different organization, you can set the `PULUMI_ORG` environment variable when adding the server.

4. Verify both MCP servers are configured:
   ```bash
   claude mcp list
   ```

   Expected output:
   ```
   Checking MCP server health...

   honeycomb: https://mcp.honeycomb.io/mcp (HTTP) - ✓ Connected
   pulumi: https://mcp.ai.pulumi.com/mcp (HTTP) - ✓ Connected
   ```

5. Test by asking Claude Code:
   ```
   What Pulumi stacks do I have in my organization?
   ```

   Claude Code will use the Pulumi MCP server to query your stacks.

::alert[**Documentation**: For detailed Pulumi MCP configuration and capabilities, see: https://www.pulumi.com/docs/iac/using-pulumi/mcp-server/]{type="info"}

::alert[**MCP Architecture**: Each MCP server runs as a hosted service that Claude Code communicates with via HTTP. This keeps AI assistant logic separate from data source specifics, enabling extensibility without local installation.]{type="success"}