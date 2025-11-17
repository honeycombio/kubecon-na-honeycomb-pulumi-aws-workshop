---
title: "Module 1: Deploy the GenAI Workload"
weight: 30
---

In this module, you'll deploy a production-ready GenAI application to AWS using Pulumi. The application is an **OpenTelemetry AI Chatbot** that uses RAG (Retrieval Augmented Generation) to help developers with OpenTelemetry integration questions.

## Module Overview

**Duration:** 20 minutes

**Objectives:**
- Set up Pulumi CLI and authenticate with Pulumi Cloud
- Configure Pulumi ESC for secrets management
- Examine the infrastructure code
- Deploy the complete application stack to AWS
- Verify the deployment

## What You'll Deploy

By the end of this module, you'll have a fully functional GenAI chatbot running on AWS with the following components:

- **ECS Fargate** cluster running containerized application
- **Application Load Balancer** routing traffic to frontend and API
- **Amazon OpenSearch Service** for vector storage (RAG)
- **Amazon ECR** repository with automatically built Docker images
- **VPC** with public and private subnets across 2 Availability Zones
- **IAM roles** for secure service-to-service communication
- **CloudWatch Logs** for application logging

::alert[**Architecture Note**: The application uses AWS Bedrock (Claude 3.5 Sonnet) for AI responses and OpenSearch for semantic search over OpenTelemetry documentation. The entire stack is deployed as code using Pulumi TypeScript.]{type="info"}

## Step 1: Access Your Development Environment

1. Open the **VS Code Server URL** provided by your workshop instructor (or from CloudFormation outputs if self-paced)

2. Enter the **password** when prompted

3. Verify you're in the `/workshop/` directory:
   ```bash
   pwd
   # Should output: /workshop
   ```

4. Install Pulumi CLI and Pulumi ESC, and restart the terminal 
   ```bash
   curl -fsSL https://get.pulumi.com | sh
   curl -fsSL https://get.pulumi.com/esc/install.sh | sh
   ```

5. Install Node
   ```bash
   # Download and install nvm:
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
   \. "$HOME/.nvm/nvm.sh"
   nvm install 24
   node -v 
   npm -v 
   ```

5. Verify all required tools are installed:
   ```bash
   pulumi version
   aws --version
   node --version
   docker --version
   ```

Expected output:
- Pulumi: v3.x or later
- AWS CLI: v2.x or later
- Node.js: v18.x or later
- Docker: 20.x or later

## Step 2: Set Up Pulumi Cloud Account

1. **Create a free Pulumi Cloud account** at https://app.pulumi.com/signup

   You can sign up using:
   - GitHub
   - GitLab
   - Email address

2. **Create a Personal Access Token**:

   Once logged in to Pulumi Cloud:
   - Navigate to https://app.pulumi.com/account/tokens (or click your profile icon → **Personal Access Tokens**)
   - Click **Create token**
   - **Description**: `workshop-token` or `honeycomb-pulumi-workshop`
   - **Expiration**: Leave as default (no expiration) or set to a future date after the workshop
   - Click **Create**
   - **Important**: Copy the token value immediately - you won't be able to see it again!

3. **Login to Pulumi from your VS Code terminal**:

   ```bash
   pulumi login
   esc login
   ```

   You'll see a prompt like this:
   ```
   Manage your Pulumi stacks by logging in.
   Run `pulumi login --help` for alternative login options.
   Enter your access token from https://app.pulumi.com/account/tokens
       or hit <ENTER> to log in using your browser                   :
   ```

   Paste your access token and press Enter.

4. **Verify your login**:

   ```bash
   pulumi whoami
   ```

   Expected output:
   ```
   User: your-username
   Organizations: your-org
   Backend URL: https://api.pulumi.com
   ```

::alert[**Security Tip**: Pulumi Personal Access Tokens provide access to your infrastructure state and should be treated like passwords. Never commit them to version control or share them in public channels.]{type="warning"}

## Step 3: Set Up Honeycomb Account

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

## Step 4: Configure Pulumi ESC Environment

Pulumi ESC (Environments, Secrets, and Configuration) provides secure secrets management. We'll create an ESC environment to store all sensitive configuration.

### Option A: AWS-Hosted Workshop Event

If you're at an AWS-hosted workshop, your instructor will provide access to a pre-configured ESC environment. You can skip to Step 5.

### Option B: Self-Paced or Own AWS Account

#### Step 4a: Set Up AWS OIDC Authentication (One-Time Setup)

Before creating the workshop environment, you need to configure AWS OIDC authentication. Pulumi ESC's new onboarding wizard makes this process simple.

**What is OIDC?** OpenID Connect (OIDC) allows Pulumi ESC to assume AWS IAM roles without storing long-lived credentials. This is a **security best practice** - credentials are dynamically generated and expire after 1 hour.

**Set up AWS OIDC using the Pulumi ESC Onboarding Wizard:**

1. In Pulumi Cloud (https://app.pulumi.com), navigate to **ESC** → **Onboarding**

2. Click **Get Started** or **Create AWS Login Environment**

3. The wizard will prompt you to choose a setup method:
   - **AWS SSO (Recommended)**: Best for organizations using AWS IAM Identity Center
   - **Local Setup via Pulumi CLI**: Alternative for direct IAM user access

4. **If using AWS SSO**:
   - Enter your **AWS SSO start URL** (e.g., `https://d-1234567890.awsapps.com/start`)
   - Enter your **SSO region** (e.g., `us-east-1`)
   - Click **Continue**
   - AWS will prompt you to authorize Pulumi Cloud permissions
   - Click **Allow** to grant permissions

5. **Configure the ESC environment**:
   - **Project Name**: `pulumi-idp` (or your preferred name)
   - **Environment Name**: `auth`
   - The full environment name will be `pulumi-idp/auth`
   - Click **Create Environment**

6. **Automated Setup**: Pulumi will automatically:
   - Create an OIDC identity provider in AWS
   - Create an IAM role with a trust policy for Pulumi
   - Configure the ESC environment with `fn::open::aws-login`
   - Set up environment variables for AWS CLI tools

7. **Verify the setup**:
   ```bash
   pulumi env run pulumi-idp/auth -- aws sts get-caller-identity
   ```

   Expected output:
   ```json
   {
       "UserId": "AROAEXAMPLE:pulumi-environments-session",
       "Account": "123456789012",
       "Arn": "arn:aws:sts::123456789012:assumed-role/pulumi-demo-org-deployments-oidc/pulumi-environments-session"
   }
   ```

::alert[**One-Time Setup**: You only need to create the `pulumi-idp/auth` environment once. All your workshop environments can import this shared credential environment. Learn more at https://www.pulumi.com/blog/esc-new-onboarding/]{type="info"}

#### Step 4b: Create Workshop-Specific ESC Environment

Now create the workshop-specific environment that imports the AWS credentials:

1. In Pulumi Cloud, navigate to **ESC** → **Environments**

2. Click **Create Environment**
   - Organization: (your organization)
   - Environment name: `honeycomb-pulumi-workshop/ws`

3. Add the following YAML configuration:

```yaml
imports:
  - pulumi-idp/auth  # Provides AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)

values:
  app:
    opensearchMasterPassword:
      fn::secret: YourStrongPassword123!
    opensearchMasterUser: admin
    honeycombApiKey: YOUR_HONEYCOMB_API_KEY_HERE

  pulumiConfig:
    opensearchMasterPassword: ${app.opensearchMasterPassword}
    opensearchMasterUser: ${app.opensearchMasterUser}
    honeycombApiKey: ${app.honeycombApiKey}
    aws:region: us-east-1
```

**Replace the following values:**
- `YourStrongPassword123!` - A strong password for OpenSearch (min 8 characters, uppercase, lowercase, number, special char)
- `YOUR_HONEYCOMB_API_KEY_HERE` - Your Honeycomb API key from Step 3

**Understanding the Import Statement:**

The `imports` section references another ESC environment called `pulumi-idp/auth`. This imported environment contains:

```yaml
# pulumi-idp/auth environment (actual structure)
values:
  aws:
    region: us-east-1
    creds:
      fn::open::aws-login:
        oidc:
          roleArn: arn:aws:iam::123456789012:role/pulumi-demo-org-deployments-oidc
          sessionName: pulumi-environments-session
          duration: 1h

  environmentVariables:
    AWS_ACCESS_KEY_ID: ${aws.creds.accessKeyId}
    AWS_SECRET_ACCESS_KEY: ${aws.creds.secretAccessKey}
    AWS_SESSION_TOKEN: ${aws.creds.sessionToken}
    AWS_REGION: ${aws.region}

  pulumiConfig:
    aws:region: ${aws.region}
```

**Key Features:**
- Uses **OIDC authentication** (`fn::open::aws-login`) to assume an AWS IAM role
- No static credentials stored - credentials are dynamically generated
- Session duration: 1 hour
- Automatically exports AWS environment variables for CLI tools

**Why Use Imports Instead of One Large Environment?**

You *could* write everything in a single ESC environment without imports:

```yaml
# Alternative: Everything in one environment (NOT recommended)
values:
  environmentVariables:
    AWS_ACCESS_KEY_ID: <your-aws-access-key>
    AWS_SECRET_ACCESS_KEY: <your-aws-secret-key>
    AWS_SESSION_TOKEN: <optional-session-token>

  app:
    opensearchMasterPassword:
      fn::secret: YourStrongPassword123!
    honeycombApiKey: YOUR_HONEYCOMB_API_KEY_HERE
  # ... rest of config
```

However, using imports provides significant benefits:

✅ **Centralized Management**: Update AWS credentials in `pulumi-idp/auth` once, and all environments that import it automatically get the changes

✅ **Segregation of Responsibility**: Infrastructure team manages `pulumi-idp/auth` (AWS credentials), while application teams manage their own app-specific secrets

✅ **Reusability**: Multiple workshop environments can import the same `pulumi-idp/auth` without duplicating AWS credentials

✅ **Security**: Limit who can modify AWS credentials separately from who can modify application secrets

::alert[**Production Pattern**: In enterprise environments, you typically have a hierarchy of ESC environments: base credentials → team-specific configs → application-specific secrets. This allows teams to share common infrastructure while maintaining isolated application secrets.]{type="info"}

**Key Configuration Points:**
- The `imports` section brings in AWS credentials from `pulumi-idp/auth`
- `fn::secret:` tells Pulumi ESC to encrypt these values
- `${app.opensearchMasterPassword}` references values within the same environment
- `pulumiConfig` values become available as Pulumi stack configuration

::alert[**Note**: The `pulumi-idp/auth` import provides AWS credentials. If this import is not available in your organization, you'll need to manually add AWS credentials to the `values` section as shown in the alternative example above. Contact your Pulumi administrator for access to shared credential environments.]{type="warning"}

4. Click **Save**

5. **Test your ESC environment** from the terminal:

   ```bash
   pulumi env get honeycomb-pulumi-workshop/ws
   ```

   This should show your environment configuration (secrets will be hidden).

6. **Verify AWS credentials** work:

   ```bash
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws sts get-caller-identity
   ```

   Expected output:
   ```json
   {
       "UserId": "AIDACKCEVSQ6C2EXAMPLE",
       "Account": "123456789012",
       "Arn": "arn:aws:iam::123456789012:user/your-username"
   }
   ```

::alert[**Troubleshooting**: If `aws sts get-caller-identity` fails, ensure the `pulumi-idp/auth` import is configured correctly or manually add AWS credentials to your ESC environment.]{type="warning"}

## Step 5: Clone the Workshop Repository

1. Clone the application repository:
   ```bash
   cd /workshop
   git clone https://github.com/dirien/ai-workshop.git
   cd ai-workshop
   ```

2. Explore the project structure:
   ```bash
   ls -la
   ```

   Key directories:
   - `server/` - Express.js backend with RAG implementation
   - `client/` - React frontend
   - `pulumi/` - Infrastructure as Code (Pulumi TypeScript)
   - `scripts/` - Utility scripts including data ingestion
   - `Dockerfile` - Container build configuration

## Step 6: Examine the Infrastructure Code

Before deploying, let's understand what Pulumi will create:

1. Open the Pulumi infrastructure code:
   ```bash
   cd pulumi
   cat index.ts
   ```

2. **Review key components in `pulumi/index.ts`**:

   **ECR Repository with Vulnerability Scanning:**
   ```typescript
   const ecrRepository = new aws.ecr.Repository(`${appName}-app`, {
       name: `${appName}-app`,
       imageTagMutability: "MUTABLE",
       imageScanningConfiguration: {
           scanOnPush: true, // Enable vulnerability scanning
       },
       encryptionConfigurations: [{
           encryptionType: "AES256", // Server-side encryption
       }],
       forceDelete: true,
       tags: tags,
   });
   ```

   **Automated Docker Image Build and Push:**
   ```typescript
   const image = new docker.Image(`${appName}-image`, {
       imageName: pulumi.interpolate`${ecrRepository.repositoryUrl}:${environment}`,
       build: {
           context: "../", // Build from the parent directory
           dockerfile: "../Dockerfile",
           platform: "linux/amd64",
           args: {
               NODE_ENV: "production",
           },
       },
       registry: {
           server: ecrRepository.repositoryUrl,
           username: authToken.userName,
           password: authToken.password,
       },
   }, {dependsOn: [ecrRepository]});
   ```

   **VPC with Multi-AZ Configuration:**
   ```typescript
   const vpc = new awsx.ec2.Vpc(`${appName}-vpc`, {
       cidrBlock: "10.0.0.0/16",
       numberOfAvailabilityZones: 2,
       natGateways: {
           strategy: "Single", // Use single NAT gateway to reduce costs
       },
       tags: tags,
   });
   ```

   **OpenSearch Domain with k-NN for Vector Search:**
   ```typescript
   const openSearchDomain = new aws.opensearch.Domain(`${appName}-opensearch`, {
       domainName: `${appName}-${environment}`,
       engineVersion: "OpenSearch_3.1",
       clusterConfig: {
           instanceType: "m8g.large.search",
           instanceCount: 2,
       },
       ebsOptions: {
           ebsEnabled: true,
           volumeSize: 100,
           volumeType: "gp3",
       },
       encryptAtRest: { enabled: true },
       nodeToNodeEncryption: { enabled: true },
       domainEndpointOptions: {
           enforceHttps: true,
           tlsSecurityPolicy: "Policy-Min-TLS-1-2-2019-07",
       },
       vpcOptions: {
           subnetIds: [vpc.privateSubnetIds[0]],
           securityGroupIds: [openSearchSecurityGroup.id],
       },
   });
   ```

   **ECS Task Definition with OpenTelemetry Configuration:**
   ```typescript
   const taskDefinition = new aws.ecs.TaskDefinition(`${appName}-task`, {
       family: `${appName}-app`,
       cpu: "512",    // 0.5 vCPU
       memory: "1024", // 1 GB RAM
       networkMode: "awsvpc",
       requiresCompatibilities: ["FARGATE"],
       executionRoleArn: ecsTaskExecutionRole.arn,
       taskRoleArn: ecsTaskRole.arn,
       containerDefinitions: {
           environment: [
               {name: "BEDROCK_MODEL", value: "anthropic.claude-3-5-sonnet-20240620-v1:0"},
               {name: "OPENSEARCH_ENDPOINT", value: `https://${opensearchEndpoint}`},
               // OpenTelemetry Configuration
               {name: "HONEYCOMB_DATASET", value: `${appName}-${environment}`},
               {name: "OTEL_SERVICE_NAME", value: `${appName}-backend`},
               {name: "OTEL_EXPORTER_OTLP_ENDPOINT", value: "https://api.honeycomb.io"},
               {name: "OTEL_EXPORTER_OTLP_PROTOCOL", value: "http/protobuf"},
           ],
           secrets: [
               {name: "HONEYCOMB_API_KEY", valueFrom: `${secretArn}:HONEYCOMB_API_KEY::`},
               {name: "OTEL_EXPORTER_OTLP_HEADERS", valueFrom: `${secretArn}:OTEL_EXPORTER_OTLP_HEADERS::`},
           ],
       }
   });
   ```

   **Application Load Balancer with Health Checks:**
   ```typescript
   const alb = new aws.lb.LoadBalancer(`${appName}-alb`, {
       loadBalancerType: "application",
       subnets: vpc.publicSubnetIds,
       securityGroups: [albSecurityGroup.id],
   });

   const targetGroup = new aws.lb.TargetGroup(`${appName}-tg`, {
       port: 3001,
       protocol: "HTTP",
       targetType: "ip",
       vpcId: vpc.vpcId,
       healthCheck: {
           enabled: true,
           path: "/api/health",
           healthyThreshold: 2,
           unhealthyThreshold: 3,
           timeout: 5,
           interval: 30,
           matcher: "200",
       },
   });
   ```

   **Stack Exports:**
   ```typescript
   export const albUrl = pulumi.interpolate`http://${alb.dnsName}`;
   export const openSearchEndpoint = openSearchDomain.endpoint;
   export const ecsClusterName = cluster.name;
   export const secretsManagerSecretArn = secretsManagerSecret.arn;
   ```

3. **Review the Dockerfile:**

   ```dockerfile
   # syntax=docker/dockerfile:1
   # Build stage
   FROM node:18-alpine AS builder

   WORKDIR /app

   # Copy package files for root and client
   COPY package*.json ./
   COPY client/package*.json ./client/

   # Install ALL dependencies (including dev deps for build) with cache mount
   RUN --mount=type=cache,target=/root/.npm \
       npm install --production && \
       cd client && npm install --production

   # Copy only backend, frontend, and scripts (avoid copying entire directory)
   COPY server ./server
   COPY client ./client
   COPY scripts ./scripts

   # Build the React frontend
   RUN cd client && npm run build

   # Production stage
   FROM node:18-alpine

   WORKDIR /app

   # Copy package files
   COPY package*.json ./

   # Install ONLY production dependencies with cache mount
   RUN --mount=type=cache,target=/root/.npm \
       npm install --production

   # Copy built application from builder
   COPY --from=builder /app/server ./server
   COPY --from=builder /app/scripts ./scripts
   COPY --from=builder /app/client/build ./client/build

   # Create non-root user
   RUN addgroup -g 1001 -S nodejs && \
       adduser -S nodejs -u 1001 && \
       chown -R nodejs:nodejs /app

   USER nodejs

   # Expose port
   EXPOSE 3001

   # Health check
   HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
     CMD node -e "require('http').get('http://localhost:3001/api/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

   # Start application
   CMD ["node", "server/index.js"]
   ```

   **Key Optimization Features:**

   - **Multi-Stage Build**: Two separate stages reduce final image size
     - **Builder stage**: Compiles React frontend (includes dev dependencies)
     - **Production stage**: Only runtime dependencies (no build tools)

   - **Build Cache Optimization**: `--mount=type=cache,target=/root/.npm`
     - Caches npm packages across builds
     - Dramatically speeds up subsequent builds (3-5 minutes → 30-60 seconds)
     - Shared across all builds on the same machine

   - **Layer Caching Strategy**:
     - Copy `package*.json` files first
     - Install dependencies before copying source code
     - Leverages Docker's layer caching - dependencies only reinstall when package.json changes

   - **Security Best Practices**:
     - Runs as non-root user (`nodejs:nodejs`)
     - Minimal attack surface with Alpine Linux base

   - **Health Check**: Built-in health monitoring for ECS
     - Checks `/api/health` endpoint every 30 seconds
     - 40-second startup grace period for application initialization

::alert[**Infrastructure as Code Benefits**: This entire application stack is defined in ~470 lines of TypeScript. Pulumi handles dependency ordering, resource creation, and state management automatically.]{type="info"}

## Step 7: Initialize Pulumi Stack

1. Navigate to the Pulumi directory:
   ```bash
   cd /workshop/ai-workshop/pulumi
   ```

2. Install Pulumi dependencies:
   ```bash
   pulumi install
   ```

3. Initialize a new stack:
   ```bash
   pulumi stack init ws
   ```

4. Configure the stack to use your ESC environment:
   ```bash
   pulumi config env add honeycomb-pulumi-workshop/ws
   ```

   This creates/updates `Pulumi.ws.yaml` with:
   ```yaml
   environment:
     - honeycomb-pulumi-workshop/ws
   ```

## Step 8: Preview the Infrastructure

Before deploying, preview what Pulumi will create:

```bash
pulumi preview
```

Review the output. You should see Pulumi plans to create approximately:
- 50+ resources including VPC, subnets, security groups, ECS cluster, OpenSearch domain, ALB, etc.
- Docker image build steps
- IAM roles and policies

::alert[**Preview Benefits**: Pulumi's preview shows exactly what will change before any resources are created. This is similar to `terraform plan` but with full programming language support.]{type="info"}

## Step 9: Deploy the Infrastructure

Now deploy the complete stack:

```bash
pulumi up --yes
```

**What happens during deployment:**

1. **ECR Repository** is created (~30 seconds)
2. **Docker Image** is built from Dockerfile (~3-5 minutes)
   - Installs Node.js dependencies
   - Builds React frontend
   - Creates production container
3. **Docker Image** is pushed to ECR (~1-2 minutes)
4. **VPC and Networking** resources are created (~2-3 minutes)
5. **Security Groups** are configured
6. **OpenSearch Domain** is provisioned (~10-15 minutes) ⏱️
7. **ECS Cluster and Service** are created (~2-3 minutes)
8. **Application Load Balancer** is configured (~2-3 minutes)
9. **CloudWatch Logs** and IAM roles are set up

**Total deployment time: ~15-20 minutes** (mostly waiting for OpenSearch domain creation)

::alert[**Coffee Break Time**: The OpenSearch domain creation takes 10-15 minutes. This is a good time to grab coffee or review the architecture diagram!]{type="info"}

## Step 10: Verify the Deployment

Once the deployment completes, verify everything is working:

1. Get the application URL:
   ```bash
   pulumi stack output albUrl
   ```

   Copy this URL (e.g., `http://otel-ai-chatbot-alb-1234567.us-east-1.elb.amazonaws.com`)

2. Check the health endpoint:
   ```bash
   curl $(pulumi stack output albUrl)/api/health
   ```

   Expected output:
   ```json
   {
     "status": "healthy",
     "timestamp": "2025-11-10T22:11:53.771Z",
     "environment": "production",
     "availableProviders": [
       "bedrock"
     ]
   }
   ```

3. Open the application URL in your browser. You should see the chatbot interface.

4. Try asking a test question (it won't work yet because we haven't ingested documentation):
   - "What is OpenTelemetry?"
   - You'll get a response but without RAG context

## Step 11: Ingest Documentation for RAG

The application uses RAG (Retrieval Augmented Generation) to provide contextually relevant answers. We need to populate the OpenSearch vector database with technical documentation.

The application provides an admin API endpoint that automatically ingests:
- **OpenTelemetry documentation** - Core concepts, instrumentation, semantic conventions
- **Honeycomb Pulumi provider documentation** - Infrastructure as Code patterns for observability

### Option A: Use the Ingest-All API Endpoint (Recommended)

This is the easiest method and requires just a single HTTP request:

1. **Trigger the ingestion process**:
   ```bash
   cd /workshop/ai-workshop/pulumi
   curl -X POST "$(pulumi stack output albUrl)/api/admin/ingest-all" \
     -H "Content-Type: application/json"
   ```

   **What happens during ingestion:**
   - Resets the vector store (deletes existing data)
   - Ingests OpenTelemetry documentation (~7 documents, 55 chunks)
   - Ingests Honeycomb Pulumi provider documentation (~6 documents, 84 chunks)
   - Generates embeddings using AWS Bedrock (Titan Embeddings model)
   - Stores vectors in OpenSearch with k-NN index

   **Ingestion time: ~1-2 minutes** for all documentation

   Expected output:
   ```json
   {
     "success": true,
     "data": {
       "message": "Documentation ingestion completed",
       "otelDocs": {
         "documentsIngested": 7,
         "chunksCreated": 55
       },
       "honeycombPulumiDocs": {
         "documentsIngested": 6,
         "chunksCreated": 84
       },
       "totalDocuments": 13,
       "totalChunks": 139
     }
   }
   ```

2. **Verify ingestion completed**:
   ```bash
   curl "$(pulumi stack output albUrl)/api/admin/vector-store/info"
   ```

   Expected output:
   ```json
   {
     "success": true,
     "data": {
       "indexName": "otel_knowledge",
       "initialized": true,
       "documentCount": 139,
       "sizeInBytes": 1987783
     }
   }
   ```

   The `documentCount` should match the total chunks (139) from the ingestion response.

::alert[**Why Multiple Documents?** The ingestion process chunks large documents into smaller pieces for better semantic search. Each chunk becomes a separate vector in OpenSearch, allowing for more precise retrieval during RAG queries.]{type="info"}

### Option B: Manual Script (Alternative)

If you prefer to run the ingestion script locally or need more control:

1. **Set environment variables**:
   ```bash
   cd /workshop/ai-workshop
   export OPENSEARCH_ENDPOINT=$(cd pulumi && pulumi stack output openSearchEndpoint)
   export OPENSEARCH_USERNAME=admin
   export OPENSEARCH_PASSWORD="<your-opensearch-password-from-ESC>"
   export USE_OPENSEARCH=true
   ```

   **Note**: Replace `<your-opensearch-password-from-ESC>` with the OpenSearch password from your Pulumi ESC environment.

2. **Run the ingestion script**:
   ```bash
   node scripts/ingest-data.js
   ```

   This script only ingests OpenTelemetry documentation. Use Option A to include Honeycomb Pulumi docs.

## Step 12: Test the Application

Now test the complete application with RAG enabled:

1. Open the application URL in your browser:
   ```bash
   pulumi stack output albUrl
   ```

2. Ask OpenTelemetry-specific questions:
   - "How do I instrument Express.js with OpenTelemetry?"
   - "What are semantic conventions?"
   - "How do I create custom spans?"

3. Observe that the bot now provides detailed, contextually relevant answers with:
   - Source attribution (which document was used)
   - Relevance scores
   - Code examples

::alert[**Success!** You've deployed a production-ready GenAI application with RAG capabilities. The application uses AWS Bedrock for LLM responses and OpenSearch for semantic search over OpenTelemetry documentation.]{type="success"}

## Step 13: Explore ECS and CloudWatch Logs

AWS CLI commands require credentials from your Pulumi ESC environment. Use `pulumi env run` to execute commands with OIDC-based credentials.

1. View ECS service status:
   ```bash
   CLUSTER_NAME=$(pulumi stack output ecsClusterName)

   # Get the service ARN
   SERVICE_ARN=$(pulumi env run honeycomb-pulumi-workshop/ws -i -- \
     aws ecs list-services --cluster $CLUSTER_NAME --query 'serviceArns[0]' --output text)

   # Extract service name from ARN
   SERVICE_NAME=$(echo $SERVICE_ARN | awk -F'/' '{print $NF}')

   # Describe the service
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws ecs describe-services \
     --cluster $CLUSTER_NAME \
     --services $SERVICE_NAME \
     --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}'
   ```

   Expected output:
   ```json
   {
       "Status": "ACTIVE",
       "RunningCount": 1,
       "DesiredCount": 1
   }
   ```

2. View application logs in CloudWatch:
   ```bash
   # Find the log group name (has Pulumi-generated suffix)
   LOG_GROUP=$(pulumi env run honeycomb-pulumi-workshop/ws -i -- \
     aws logs describe-log-groups --log-group-name-prefix otel-ai-chatbot-logs \
     --query 'logGroups[0].logGroupName' --output text)

   # Tail the logs
   pulumi env run honeycomb-pulumi-workshop/ws -i -- aws logs tail $LOG_GROUP --follow
   ```

   Press `Ctrl+C` to stop tailing logs.

::alert[**Why `pulumi env run`?** AWS CLI commands need credentials. The `pulumi env run honeycomb-pulumi-workshop/ws -i --` wrapper executes commands with OIDC-based AWS credentials from your ESC environment, which are dynamically generated and short-lived (1 hour).]{type="info"}

3. Check all Pulumi outputs:
   ```bash
   pulumi stack output
   ```

   This shows:
   - Application URL
   - ECS cluster and service names
   - OpenSearch endpoint
   - ECR repository URL

## Module Summary

Congratulations! You've successfully:

- ✅ Set up Pulumi Cloud and Pulumi ESC for secure configuration management
- ✅ Deployed a complete GenAI application stack to AWS using Infrastructure as Code
- ✅ Configured ECS Fargate with automated Docker builds
- ✅ Provisioned Amazon OpenSearch with k-NN for vector search
- ✅ Set up Application Load Balancer for production traffic
- ✅ Ingested OpenTelemetry documentation for RAG capabilities
- ✅ Verified the application is running and responding to queries

## What's Next?

In **Module 2**, you'll instrument this application with OpenTelemetry to collect detailed telemetry data and send it to Honeycomb for observability.

---

## Troubleshooting

### Deployment Fails with "Docker daemon not running"

**Solution**: Start Docker daemon:
```bash
sudo systemctl start docker
```

### OpenSearch Domain Creation Timeout

**Symptom**: Deployment stuck on OpenSearch for >20 minutes

**Solution**: OpenSearch domains can take 10-20 minutes. If it exceeds 25 minutes, check AWS Console for errors:
```bash
pulumi env run honeycomb-pulumi-workshop/ws -i -- aws opensearch describe-domain --domain-name otel-ai-chatbot-ws
```

### ECS Tasks Failing Health Checks

**Solution**: Check CloudWatch Logs for application errors:
```bash
pulumi env run honeycomb-pulumi-workshop/ws -i -- aws logs tail /aws/ecs/otel-ai-chatbot-logs --since 10m
```

Common issues:
- OpenSearch not accessible (check security group rules)
- AWS Bedrock not enabled in region (verify in AWS Console)
- Environment variables not set correctly (review ECS task definition)

### Application Returns 503 Errors

**Solution**: Verify ECS service has running tasks:
```bash
pulumi env run honeycomb-pulumi-workshop/ws -i -- aws ecs list-tasks --cluster $(pulumi stack output ecsClusterName)
```

If no tasks are running, check ECS service events for deployment failures.

---

## Additional Resources

- [Pulumi AWS Documentation](https://www.pulumi.com/docs/clouds/aws/)
- [Pulumi ESC Documentation](https://www.pulumi.com/docs/pulumi-cloud/esc/)
- [Amazon ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Amazon OpenSearch k-NN Documentation](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/knn.html)
