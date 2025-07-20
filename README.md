# Alert Self-Resolution Lab for EKS + JSM/JIRA Integration

## Problem Statement
You have a Grafana instance running in a self-hosted pod on EKS. When alerts are triggered (e.g., high CPU, unreachable instances), they create tickets in JSM/JIRA. However, when the underlying condition is resolved, the alerts do not automatically clear from JSM/JIRA, leading to:

- Manual ticket cleanup overhead
- Inaccurate incident metrics  
- Alert fatigue from stale tickets

## Solution Overview
This lab demonstrates how to implement **automatic alert resolution** using:
1. **Prometheus** for monitoring and alerting
2. **Alertmanager** for routing and webhook delivery
3. **Webhook integration** with JSM/JIRA for ticket lifecycle management

### Local Testing Environment
This entire lab runs locally on **minikube**, simulating your EKS environment:

| Local Component | Represents in Production |
|----------------|-------------------------|
| Minikube cluster | Your EKS cluster |
| Webhook receiver | Your JSM/JIRA system |
| Test-app service | Your production applications |
| Prometheus alerts | Your Grafana alerts |

**The webhook receiver acts as a mock JSM/JIRA system**, logging what would be actual ticket creation and closure API calls.

## Key Components

### 1. Alert Rules (`prometheus-alert-rules.yaml`)
- **TestAppDown**: Fires when service is unavailable (`up{job="test-app-service"} == 0`) and automatically resolves when service recovers (`up{job="test-app-service"} == 1`)

### ⚠️ **Important: Self-Resolution Pattern**
This lab uses the **correct pattern** for alert self-resolution:

✅ **CORRECT**: Single alert that fires and resolves naturally
- `TestAppDown` fires when `up == 0`
- `TestAppDown` resolves when `up == 1`
- Alertmanager sends both "firing" and "resolved" webhooks

❌ **INCORRECT**: Separate alerts for problems and recovery
- ~~`TestAppDown` fires when `up == 0`~~
- ~~`TestAppRecovered` fires when `up == 1` (stays firing forever!)~~

**Why the incorrect pattern fails**: Recovery alerts stay in firing state permanently when the service is healthy, creating noise and preventing proper self-resolution.

### 2. Alertmanager Configuration (`alertmanager-config.yaml`)
**Critical setting for self-resolution:**
```yaml
webhook_configs:
- url: 'http://webhook-receiver-service.monitoring.svc.cluster.local:8080/webhook'
  send_resolved: true  # 🔑 This enables resolution notifications
```

### 3. Webhook Integration Logic
- **FIRING alerts** → CREATE JSM/JIRA tickets
- **RESOLVED alerts** → CLOSE JSM/JIRA tickets

## Testing the Setup

### Prerequisites: Verify Health
```bash
./health_check.sh
```

### Apply Enhanced Configuration  
```bash
kubectl apply -f alertmanager-config-enhanced.yaml
kubectl rollout restart statefulset alertmanager-prometheus-stack-kube-prom-alertmanager -n monitoring
```

### Local Testing Options

You have **4 options** to test alert self-resolution locally on minikube:

#### **Option 1: Automated Demo (Recommended for First Test)**
```bash
./demo-local.sh
```
- Automatically triggers and resolves alerts
- Shows clear JSM/JIRA simulation
- Best for understanding the workflow

#### **Option 2: Comprehensive Test**
```bash
./test-self-resolution.sh
```
- Complete end-to-end testing
- Technical output with detailed metrics
- Shows Prometheus and Alertmanager status

#### **Option 3: Real-Time Interactive Monitoring**
**Terminal 1:** Start monitoring
```bash
./monitor-webhooks.sh
```
**Terminal 2:** Trigger alerts manually
```bash
# Trigger alert (simulate JSM ticket creation)
kubectl scale deployment test-app --replicas=0

# Wait 60 seconds, then resolve alert (simulate JSM ticket closure)
kubectl scale deployment test-app --replicas=1
```

#### **Option 4: Manual with Log Monitoring**
**Terminal 1:** Watch webhook activity
```bash
kubectl logs -f -n monitoring deployment/webhook-receiver
```
**Terminal 2:** Control the testing
```bash
kubectl scale deployment test-app --replicas=0  # Trigger
# Wait 60 seconds
kubectl scale deployment test-app --replicas=1  # Resolve
```

### What You'll See in Each Test
- **Alert fires** when app goes down → Webhook called (would CREATE JSM ticket)
- **Alert resolves** when app recovers → Webhook called with "resolved" status (would CLOSE JSM ticket)
- This simulates **exactly what will happen** in your EKS environment with real JSM/JIRA

## Expected Webhook Flow

### When Alert Fires:
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
      "summary": "Test application is down"
    },
    "startsAt": "2025-07-20T10:30:00Z"
  }]
}
```
**Action**: Create JSM/JIRA ticket

### When Alert Resolves:
```json
{
  "status": "resolved", 
  "alerts": [{
    "status": "resolved",
    "labels": {
      "alertname": "TestAppDown",
      "service": "test-app"
    },
    "startsAt": "2025-07-20T10:30:00Z",
    "endsAt": "2025-07-20T10:35:00Z"
  }]
}
```
**Action**: Close JSM/JIRA ticket

## Production JSM/JIRA Integration

### For JSM Cloud:
```bash
# Create ticket (on firing)
curl -X POST \
  -H "Authorization: Bearer ${JSM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "Alert: TestAppDown",
    "description": "Test application is down",
    "priority": "High",
    "labels": ["monitoring", "critical"],
    "customfield_10001": "ALERT_ID_TestAppDown_instance"
  }' \
  "https://your-domain.atlassian.net/rest/api/3/issue"

# Close ticket (on resolved)  
ISSUE_KEY=$(curl -s -H "Authorization: Bearer ${JSM_API_KEY}" \
  'https://your-domain.atlassian.net/rest/api/3/search?jql=cf[10001]~"ALERT_ID_TestAppDown"' \
  | jq -r '.issues[0].key')

curl -X POST \
  -H "Authorization: Bearer ${JSM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"transition": {"id": "31"}}' \
  "https://your-domain.atlassian.net/rest/api/3/issue/${ISSUE_KEY}/transitions"
```

### Alternative: JSM Automation Rules
Instead of custom webhooks, use JSM's built-in automation:

**Rule 1** (Create tickets):
- Trigger: Webhook received
- Condition: `webhook.status = "firing"`
- Action: Create issue

**Rule 2** (Close tickets):
- Trigger: Webhook received
- Condition: `webhook.status = "resolved"`
- Action: Find related issues and transition to Done

## Troubleshooting

### Common Issues:

1. **Alerts not firing**:
   - Check ServiceMonitor labels match Prometheus selector
   - Verify targets in Prometheus UI (`/targets`)

2. **Webhooks not received**:
   - Check Alertmanager logs: `kubectl logs -n monitoring alertmanager-prometheus-stack-kube-prom-alertmanager-0`
   - Verify `send_resolved: true` is set

3. **Resolution not working**:
   - Ensure `send_resolved: true` is set in Alertmanager configuration
   - Check alert routing in Alertmanager config
   - Verify the alert condition can naturally resolve (e.g., `up == 0` resolves when `up == 1`)

### Debug Commands:
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090

# Check Alertmanager config
kubectl get secret alertmanager-prometheus-stack-alertmanager -n monitoring -o yaml

# Test webhook endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"status":"firing","alerts":[{"labels":{"alertname":"test"}}]}' \
  http://webhook-receiver-service.monitoring.svc.cluster.local:8080/webhook
```

## Files in this Lab:

### Testing Scripts:
- `health_check.sh` - Verify all services are running
- `demo-local.sh` - **Recommended**: Automated demo with JSM simulation
- `test-self-resolution.sh` - Complete end-to-end technical test
- `monitor-webhooks.sh` - Real-time webhook monitoring
- `simple-webhook-test.sh` - Simple webhook verification test

### Configuration Files:
- `alertmanager-config.yaml` - Basic webhook configuration
- `alertmanager-config-enhanced.yaml` - Production-ready configuration
- `prometheus-alert-rules.yaml` - **Corrected** alert definitions with examples and documentation
- `webhook-receiver.yaml` - Mock webhook endpoint for testing
- `test-app.yaml` - Test application to trigger alerts

### Documentation:
- `jsm-integration-guide.sh` - JSM/JIRA integration examples and guide
- `README.md` - This comprehensive documentation

## Next Steps:

1. **Test this lab setup** to understand the flow
2. **Adapt webhook payload** format for your JSM/JIRA instance
3. **Implement authentication** for production webhooks
4. **Add error handling** and retry logic
5. **Monitor webhook delivery** success rates
6. **Test in staging** before production deployment

The key insight is that `send_resolved: true` in Alertmanager configuration enables automatic ticket closure when conditions improve, solving your original problem of alerts not clearing from JSM/JIRA.
