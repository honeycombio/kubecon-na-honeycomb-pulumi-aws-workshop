---
title: "Step 4: Examine the Infrastructure Code"
weight: 34
---

Before deploying, let's understand what Pulumi will create:

1. **Explore the project structure in VS Code Server**:

   The workshop repository contains a well-organized GenAI application with the following structure:

   **Key directories and their purposes:**

   - **`client/`** - React frontend application
     - Contains the user interface for the AI chatbot
     - Built with React and served alongside the backend

   - **`server/`** - Express.js backend with RAG implementation
     - Handles API requests and AI chat logic
     - Integrates with AWS Bedrock (Claude) and OpenSearch
     - Implements OpenTelemetry instrumentation

   - **`pulumi/`** - Infrastructure as Code (Pulumi TypeScript)
     - Defines all AWS resources (ECS, OpenSearch, VPC, ALB, etc.)
     - Contains `index.ts` with complete infrastructure definition
     - Configuration files: `Pulumi.yaml`, `Pulumi.ws.yaml`

   - **`scripts/`** - Utility scripts
     - Data ingestion scripts for populating OpenSearch vector store
     - Documentation processing utilities

   - **`.devcontainer/`** - Development container configuration
     - VS Code dev container setup for consistent environments

   - **`Dockerfile`** - Multi-stage container build configuration
     - Builds both frontend and backend into a single optimized image

   - **Configuration files** (root directory):
     - `package.json` - Root Node.js dependencies
     - `.gitignore` - Git ignore patterns
     - `.dockerignore` - Docker build exclusions
     - `env.example` - Environment variable template
     - `README.md` - Project documentation

   **Open the Pulumi infrastructure code** by clicking on the `pulumi` folder in the Explorer sidebar, then clicking on `index.ts`:

   :image[Pulumi index.ts File]{src="/static/images/pulumi/vscode-pulumi-index-ts.png" width=750}

   This file contains the complete infrastructure definition, including ECR repositories, VPC configuration, ECS cluster, an OpenSearch Serverless vector-search collection, and Application Load Balancer setup.

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
   const image = new dockerBuild.Image(`${appName}-image`, {
       tags: [pulumi.interpolate`${ecrRepository.repositoryUrl}:${environment}`],
       push: true,
       context: {
           location: "../",
       },
       dockerfile: {
           location: "../Dockerfile",
       },
       platforms: ["linux/arm64"],
       buildArgs: {
           NODE_ENV: "production",
       },
       registries: [{
           address: ecrRepository.repositoryUrl,
           username: authToken.userName,
           password: authToken.password,
       }],
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

   **OpenSearch Serverless VECTORSEARCH Collection:**
   ```typescript
   // Encryption + network policies (omitted here — see pulumi/index.ts).
   // Data access policy grants the ECS task role + deploying caller full
   // index/collection permissions via SigV4 — no master user/password.
   const openSearchCollection = new aws.opensearch.ServerlessCollection(
     `${appName}-aoss`,
     {
       name: collectionName,
       type: "VECTORSEARCH",
       description: "Vector search for OpenTelemetry docs RAG",
       tags: tags,
     },
     {dependsOn: [encryptionPolicy, networkPolicy, dataAccessPolicy]},
   );
   ```

   ::alert[**Why Serverless?**: Managed OpenSearch domains take 15-60 minutes to provision and require master-user password management. Serverless `VECTORSEARCH` collections come up in 1-3 minutes, auto-scale on OCUs, and use IAM/SigV4 for auth — which fits the workshop's "watch it deploy live" pacing.]{type="success"}

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
               {name: "BEDROCK_MODEL", value: "us.anthropic.claude-haiku-4-5-20251001-v1:0"},
               {name: "OPENSEARCH_ENDPOINT", value: opensearchEndpoint},
               {name: "OPENSEARCH_SERVICE", value: "aoss"},
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
   export const ecsTaskDefinitionArn = taskDefinition.arn;
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