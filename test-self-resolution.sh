#!/bin/bash

# Alert Self-Resolution Test Script
# This script demonstrates how alerts fire and automatically resolve when conditions clear

set -e

echo "🚀 ALERT SELF-RESOLUTION TEST"
echo "=============================="
echo ""

# Function to check webhook logs
check_webhook_logs() {
    echo "📋 Recent webhook activity:"
    kubectl logs -n monitoring deployment/webhook-receiver --tail=20 | grep -E "(WEBHOOK RECEIVED|Alert:|Status:|ALERT FIRING|ALERT RESOLVED)" | tail -10 || echo "No webhook activity yet"
    echo ""
}

# Function to check alert status in Prometheus
check_prometheus_alerts() {
    echo "🔍 Current alerts in Prometheus:"
    kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090 >/dev/null 2>&1 &
    PROM_PID=$!
    sleep 3
    
    # Check if any TestApp alerts are active
    ALERTS=$(curl -s "http://localhost:9090/api/v1/alerts" | jq -r '.data.alerts[] | select(.labels.alertname | contains("TestApp")) | "\(.labels.alertname): \(.state)"' 2>/dev/null || echo "No TestApp alerts found")
    
    if [ -z "$ALERTS" ]; then
        echo "✅ No TestApp alerts currently active"
    else
        echo "$ALERTS"
    fi
    
    kill $PROM_PID 2>/dev/null
    echo ""
}

# Function to check Alertmanager status
check_alertmanager_alerts() {
    echo "📢 Current alerts in Alertmanager:"
    kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-alertmanager 9093:9093 >/dev/null 2>&1 &
    AM_PID=$!
    sleep 3
    
    # Check if any alerts are in Alertmanager
    AM_ALERTS=$(curl -s "http://localhost:9093/api/v1/alerts" | jq -r '.data[] | select(.labels.alertname | contains("TestApp")) | "\(.labels.alertname): \(.status.state)"' 2>/dev/null || echo "No TestApp alerts in Alertmanager")
    
    if [ -z "$AM_ALERTS" ]; then
        echo "✅ No TestApp alerts in Alertmanager"
    else
        echo "$AM_ALERTS"
    fi
    
    kill $AM_PID 2>/dev/null
    echo ""
}

echo "📊 Step 1: Checking initial state"
echo "Current test-app status:"
kubectl get deployment test-app --no-headers 2>/dev/null || echo "test-app not deployed yet"
echo ""

check_prometheus_alerts
check_alertmanager_alerts
check_webhook_logs

echo "🔥 Step 2: Triggering alert by scaling down test-app"
kubectl scale deployment test-app --replicas=0
echo "Test app scaled to 0 replicas (this should trigger TestAppDown alert)"
echo "Waiting 60 seconds for alert to fire..."
sleep 60

echo ""
echo "📈 Step 3: Checking alert status after triggering"
check_prometheus_alerts
check_alertmanager_alerts
check_webhook_logs

echo "✅ Step 4: Resolving the issue by scaling up test-app"
kubectl scale deployment test-app --replicas=1
echo "Test app scaled back to 1 replica (this should resolve the alert)"
echo "Waiting 60 seconds for alert to resolve..."
sleep 60

echo ""
echo "🎯 Step 5: Verifying self-resolution"
check_prometheus_alerts
check_alertmanager_alerts
check_webhook_logs

echo ""
echo "=== SELF-RESOLUTION SUMMARY ==="
echo "✅ The test demonstrates alert self-resolution workflow:"
echo "1. 🔥 Alert fires when test-app becomes unavailable"
echo "2. 📢 Alertmanager sends 'firing' webhook to external system"
echo "3. ✅ Alert resolves when test-app becomes available again"
echo "4. 📢 Alertmanager sends 'resolved' webhook to external system"
echo ""
echo "💡 For JSM/JIRA integration:"
echo "- The webhook receiver simulates your ticketing system"
echo "- 'firing' webhooks should CREATE tickets"
echo "- 'resolved' webhooks should CLOSE tickets"
echo "- The 'send_resolved: true' setting in alertmanager-config.yaml is key"
echo ""
echo "🔧 To integrate with real JSM/JIRA:"
echo "1. Replace webhook URL with your JSM/JIRA webhook endpoint"
echo "2. Modify webhook payload format to match JSM/JIRA API"
echo "3. Add authentication credentials if required"
echo "4. Test thoroughly in your environment"
echo ""
echo "📋 View real-time webhook logs with:"
echo "kubectl logs -f -n monitoring deployment/webhook-receiver"
