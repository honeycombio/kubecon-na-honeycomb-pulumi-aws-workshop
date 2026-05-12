---
title: Getting Started
weight: 20
---

## Workshop Architecture

In this workshop, you'll deploy and operate a **GenAI chatbot application** that helps developers with OpenTelemetry integration. This real-world application demonstrates the complete closed-loop system for AI-powered infrastructure management:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Workshop Participants                        │
│                  (VS Code Server on EC2)                        │
│                                                                 │
│  ┌─────────────────┐   ┌──────────────────┐  ┌────────────────┐ │
│  │ Amazon Kiro CLI │   │    Pulumi CLI    │  │    kubectl     │ │
│  │ + MCP Servers   │   │  + Pulumi ESC    │  │  + AWS CLI     │ │
│  │                 │   │  + Pulumi Neo    │  │                │ │
│  └─────────────────┘   └──────────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
        ┌───────────▼──────────┐   ┌───▼──────────────┐
        │   Honeycomb          │   │   Pulumi Cloud   │
        │   (Observability)    │   │   (IaC State)    │
        │                      │   │                  │
        │  - Telemetry Data    │   │  - Stack State   │
        │  - MCP Server        │   │  - Neo Agent     │
        │  - Query API         │   │  - ESC Secrets   │
        └──────────────────────┘   └──────────────────┘
                    │
                    │ OpenTelemetry Data
                    │
        ┌───────────▼───────────────────────────────────┐
        │          AWS Account (Your Stack)             │
        │                                               │
        │  ┌──────────────┐       ┌──────────────────┐  │
        │  │ Application  │       │  Amazon OpenSearch│ │
        │  │ Load         │◄──────┤  Serverless       │ │
        │  │ Balancer     │       │  (VECTORSEARCH)   │ │
        │  └──────┬───────┘       └──────────────────┘  │
        │         │                                     │
        │  ┌──────▼───────────────────────────────────┐ │
        │  │  ECS Fargate (OTel AI Chatbot)           │ │
        │  │                                          │ │
        │  │  - React Frontend + Express API          │ │
        │  │  - OpenTelemetry Instrumentation         │ │
        │  │  - AWS Bedrock (Claude Haiku 4.5)        │ │
        │  │  - Exports traces to Honeycomb           │ │
        │  └──────────────────────────────────────────┘ │
        └───────────────────────────────────────────────┘
```

### Key Components

**Development Environment:**
- **VS Code Server on EC2**: Your complete development environment with pre-installed tools
- **Amazon Kiro CLI**: AI assistant with MCP (Model Context Protocol) server support
- **Pulumi CLI**: Infrastructure as Code tool with Pulumi ESC for secrets management
- **Pulumi Neo**: AI agent for generating infrastructure code changes

**Application Stack (Deployed during workshop):**
- **ECS Fargate**: Serverless container platform running the OTel AI Chatbot
- **Application Load Balancer**: Routes traffic to the application (frontend + API)
- **Amazon OpenSearch Serverless**: VECTORSEARCH collection for RAG (Retrieval Augmented Generation), provisions in ~1-3 minutes
- **AWS Bedrock**: Provides Claude Haiku 4.5 for AI responses
- **Amazon ECR**: Private container registry for Docker images

**Observability & Management:**
- **Honeycomb**: Observability platform for collecting and analyzing OpenTelemetry data
- **Honeycomb MCP Server**: Enables Amazon Kiro CLI to query observability data
- **Pulumi Cloud**: Manages infrastructure state and provides access to Pulumi Neo
- **Pulumi ESC**: Manages secrets and configuration securely

## Preparing for the Workshop

The workshop infrastructure (VS Code Server and baseline AWS resources) will be automatically deployed using AWS CloudFormation. During the workshop, you'll use Pulumi to deploy the application infrastructure.

**Choose your setup path:**

- **AWS Guided Event**: If you're attending an AWS-hosted workshop, follow the setup instructions [here](/0_getting-started/01-aws-event.html)
- **Self-Paced Learning**: If you're running this workshop independently, follow the setup instructions [here](/0_getting-started/02-own-account.html)

## What's Pre-Deployed (CloudFormation)

When you start the workshop, these resources are already provisioned:

✅ **VS Code Server on EC2** with CloudFront distribution for secure access
- Pre-installed: Pulumi CLI, AWS CLI, kubectl, eksctl, helm, Amazon Kiro CLI
- Configured with workshop participant IAM role
- Home folder: `/workshop/`

## What You'll Deploy During the Workshop

During the hands-on labs, you'll use Pulumi to provision:

🚀 **Amazon ECR Repository** for container images

🚀 **VPC with Public/Private Subnets** (2 Availability Zones)

🚀 **Amazon OpenSearch Serverless** VECTORSEARCH collection for k-NN vector search (provisions in ~1-3 minutes via IAM/SigV4)

🚀 **ECS Fargate Cluster and Service** running the OTel AI Chatbot

🚀 **Application Load Balancer** serving both frontend and backend API

🚀 **IAM Roles and Policies** for ECS task execution and service access

🚀 **CloudWatch Log Groups** for application logging

## What You'll Configure During the Workshop

Throughout the workshop, you'll set up and configure:

🔧 **Honeycomb Account**: Create a free account for observability data collection

🔧 **Pulumi Account**: Set up Pulumi Cloud access for state management and Neo

🔧 **Pulumi ESC Environment**: Configure secrets and AWS credentials securely

🔧 **OpenTelemetry Instrumentation**: Add automatic and manual instrumentation to the Node.js application

🔧 **Honeycomb MCP Server**: Enable Amazon Kiro CLI to query your observability data

🔧 **Pulumi MCP Server**: Enable Amazon Kiro CLI to interact with Pulumi infrastructure

🔧 **AI-Powered Remediation Workflow**: Use Amazon Kiro CLI + Pulumi Neo to diagnose and fix infrastructure issues

::alert[**Cost Management**: If you are running this workshop on your own AWS account, remember to delete all resources by following the [Clean Up Resources](/cleanup.html) section to avoid unnecessary charges. The workshop costs ~$4-5 for the 2-hour session (OpenSearch Serverless OCUs dominate). The application stack (ECS + OpenSearch Serverless + ALB) costs approximately $250/month if left running — be especially diligent about cleanup since the Serverless OCU floor is the main contributor.]{type="warning"}

## Ready to Begin?

Select your setup path above to access your development environment and start the workshop!
