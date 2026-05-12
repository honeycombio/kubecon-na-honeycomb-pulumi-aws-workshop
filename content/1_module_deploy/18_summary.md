---
title: "Module Summary"
weight: 38
---

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

### OpenSearch Serverless Collection Not Reachable

**Symptom**: ECS task logs show 403 Forbidden or `AccessDeniedException` when calling the collection endpoint.

**Solution**: The collection becomes `ACTIVE` within 1-3 minutes — if the task started before that, restart it. If errors persist after the collection is active, the data access policy is the most likely culprit:
```bash
pulumi env run honeycomb-pulumi-workshop/ws -i -- aws opensearchserverless list-collections
pulumi env run honeycomb-pulumi-workshop/ws -i -- aws opensearchserverless list-access-policies --type data
```
The policy's `Principal` list must include the ECS task role ARN.

### ECS Tasks Failing Health Checks

**Solution**: Check CloudWatch Logs for application errors:
```bash
# Find the log group name (has Pulumi-generated suffix)
LOG_GROUP=$(pulumi env run honeycomb-pulumi-workshop/ws -i -- \
  aws logs describe-log-groups --log-group-name-prefix otel-ai-chatbot-logs \
  --query 'logGroups[0].logGroupName' --output text)

pulumi env run honeycomb-pulumi-workshop/ws -i -- aws logs tail $LOG_GROUP --since 10m
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
