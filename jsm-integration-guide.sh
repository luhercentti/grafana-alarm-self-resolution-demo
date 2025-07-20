#!/bin/bash

# JSM/JIRA Integration Example for Alert Self-Resolution
# This script demonstrates how to integrate Alertmanager webhooks with JSM/JIRA

echo "🎫 JSM/JIRA INTEGRATION GUIDE FOR ALERT SELF-RESOLUTION"
echo "======================================================"
echo ""

cat << 'EOF'
## Problem Statement
When alerts fire in Grafana/Prometheus and create tickets in JSM/JIRA, 
the tickets often remain open even after the underlying issue is resolved.
This leads to:
- Manual ticket cleanup overhead
- Inaccurate incident metrics
- Alert fatigue from stale tickets

## Solution: Automated Alert Self-Resolution

### 1. Key Configuration Settings

In alertmanager-config.yaml, ensure:
```yaml
webhook_configs:
- url: 'https://your-jsm-webhook-url'
  send_resolved: true  # 🔑 CRITICAL SETTING
```

### 2. Webhook Payload Structure

FIRING Alert Example:
```json
{
  "status": "firing",
  "alerts": [{
    "status": "firing",
    "labels": {
      "alertname": "TestAppDown",
      "service": "test-app",
      "severity": "critical"
    },
    "annotations": {
      "summary": "Test application is down",
      "description": "Test application has been down for more than 30 seconds"
    },
    "startsAt": "2025-07-20T10:30:00Z"
  }]
}
```

RESOLVED Alert Example:
```json
{
  "status": "resolved",
  "alerts": [{
    "status": "resolved",
    "labels": {
      "alertname": "TestAppDown",
      "service": "test-app",
      "severity": "critical"
    },
    "annotations": {
      "summary": "Test application is down",
      "description": "Test application has been down for more than 30 seconds"
    },
    "startsAt": "2025-07-20T10:30:00Z",
    "endsAt": "2025-07-20T10:35:00Z"
  }]
}
```

### 3. JSM Integration Logic

For JSM Cloud, your webhook handler should:

A) For FIRING alerts:
```bash
# Create incident
curl -X POST \
  -H "Authorization: Bearer ${JSM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Alert: TestAppDown",
    "description": "Test application is down",
    "priority": "High",
    "labels": ["monitoring", "test-app", "critical"],
    "customfield_10001": "ALERT_ID_' + alertname + '_' + instance + '"
  }' \
  "https://your-domain.atlassian.net/rest/api/3/issue"
```

B) For RESOLVED alerts:
```bash
# Find and close incident
ISSUE_KEY=$(curl -X GET \
  -H "Authorization: Bearer ${JSM_API_KEY}" \
  'https://your-domain.atlassian.net/rest/api/3/search?jql=cf[10001]~"ALERT_ID_TestAppDown"' \
  | jq -r '.issues[0].key')

# Close the incident
curl -X POST \
  -H "Authorization: Bearer ${JSM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "transition": {"id": "31"},
    "fields": {
      "resolution": {"name": "Done"}
    }
  }' \
  "https://your-domain.atlassian.net/rest/api/3/issue/${ISSUE_KEY}/transitions"

# Add resolution comment
curl -X POST \
  -H "Authorization: Bearer ${JSM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "body": "Alert condition resolved automatically at ' + endsAt + '"
  }' \
  "https://your-domain.atlassian.net/rest/api/3/issue/${ISSUE_KEY}/comment"
```

### 4. Testing the Integration

1. Deploy the enhanced configuration:
   kubectl apply -f alertmanager-config-enhanced.yaml

2. Restart Alertmanager:
   kubectl rollout restart statefulset alertmanager-prometheus-stack-kube-prom-alertmanager -n monitoring

3. Run the self-resolution test:
   ./test-self-resolution.sh

4. Monitor webhook logs:
   kubectl logs -f -n monitoring deployment/webhook-receiver

### 5. Production Considerations

- Add authentication to your webhook endpoints
- Implement retry logic for failed webhook deliveries
- Store alert-to-ticket mappings in a database for reliability
- Add proper error handling and logging
- Consider using JSM Automation Rules for simpler integration
- Test thoroughly in staging environment first

### 6. Alternative: JSM Automation Rules

Instead of custom webhook handlers, you can use JSM's built-in automation:

Rule 1 (Create tickets):
- Trigger: Webhook received
- Condition: webhook.status = "firing"
- Action: Create issue

Rule 2 (Close tickets):
- Trigger: Webhook received  
- Condition: webhook.status = "resolved"
- Action: Find related issues and transition to Done

### 7. Monitoring the Integration

Set up alerts for:
- Webhook delivery failures
- JSM API errors
- Orphaned tickets (alerts resolved but tickets still open)
- High ticket creation/resolution rates
EOF

echo ""
echo "📋 Next Steps:"
echo "1. Apply enhanced configuration: kubectl apply -f alertmanager-config-enhanced.yaml"
echo "2. Run test: ./test-self-resolution.sh"
echo "3. Adapt webhook payload format for your JSM/JIRA instance"
echo "4. Implement proper authentication and error handling"
echo "5. Test thoroughly before production deployment"
