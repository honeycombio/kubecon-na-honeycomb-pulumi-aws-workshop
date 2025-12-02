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
   - Go to **Team Settings** → **API Keys** (or directly to `https://ui.honeycomb.io/account`)
   - Click **Create API Key** in the Ingest Keys section
   - **Key Name**: `workshop-otel` or `kubecon-workshop`
   - **Key Type**: Ensure you're creating an **Ingest Key** (not a Configuration Key)
   - **Permissions**: Enable **"Can create datasets"** permission
     - This allows the application to automatically create the `otel-ai-chatbot` dataset when sending telemetry
   - Click **Create Key**
   - **Important**: Copy the API key value immediately - you won't be able to see it again!

   Example API key format: `hc[alphanumeric string]`

3. **Note your Environment name**:
   - Look at the top-left of the Honeycomb UI
   - The environment name is usually shown as part of your team name
   - Default environment is often `production` or your team slug
   - You'll see this later when viewing traces

::alert[**API Key Types**: Honeycomb has two types of API keys. **Ingest Keys** are used to send telemetry data (traces, logs, metrics) from your applications. **Configuration Keys** are for managing Honeycomb resources via the API. For this workshop, we only need an Ingest Key.]{type="info"}

::alert[**Security Best Practice**: API keys are immutable after creation for security. Treat Honeycomb API keys like passwords - never commit them to version control or share them publicly. We'll store them securely in Pulumi ESC in the next step.]{type="warning"}

We'll use this API key in the next step to configure Pulumi ESC.