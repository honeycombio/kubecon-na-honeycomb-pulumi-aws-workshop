---
title: "Step 2: Set Up Honeycomb Account"
weight: 32
---

1. **Create a free Honeycomb account** at https://ui.honeycomb.io/signup

   You can sign up using:
   - Email address
   - Google account
   - GitHub account

2. **Create an Ingest API Key**:

   Once logged in to Honeycomb:
   - Navigate to your environment settings

   :image[Environment Settings]{src="/static/images/honeycomb/api_keys.png" width=750}

   - Click **Create Ingest API Key** 
      - **Key Name**: `workshop-otel`
      - Leave **"Can create services/datasets"** enabled. This allows the application to automatically create the `otel-ai-chatbot` dataset when sending telemetry
      - Click **Create**

   :image[Ingest API Key]{src="/static/images/honeycomb/create_ingest_key.png" width=600}
  
   - **Important**: Copy the API key value immediately - you won't be able to see it again!

   Example API key format: `hc[alphanumeric string]`

3. Note your **Environment name**:
   - Look at the top-left of the Honeycomb UI
   - The environment name is usually shown as part of your team name
   - Default environment is often `production` or your team slug
   - You'll see this later when viewing traces

::alert[**API Key Types**: Honeycomb has two types of API keys. **Ingest Keys** are used to send telemetry data (traces, logs, metrics) from your applications. **Management Keys** are for managing Honeycomb resources via the API. For this workshop, we only need an Ingest Key — the Honeycomb MCP server uses OAuth instead of an API key, so you no longer need to create a Management Key just to use MCP.]{type="info"}

::alert[**Security Best Practice**: API keys are immutable after creation for security. Treat Honeycomb API keys like passwords - never commit them to version control or share them publicly. We'll store them securely in Pulumi ESC in the next step.]{type="warning"}

We'll use this API key in the next step to configure Pulumi ESC.