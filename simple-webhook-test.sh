#!/bin/bash

# Simple webhook test to verify alert self-resolution
echo "🧪 SIMPLE WEBHOOK TEST"
echo "======================"
echo ""

# Function to check webhook logs
check_webhooks() {
    echo "📋 Checking webhook activity..."
    kubectl logs -n monitoring deployment/webhook-receiver --tail=50 | grep -E "(Webhook receiver started|WEBHOOK RECEIVED|Alert:|Status:|ALERT FIRING|ALERT RESOLVED)" | tail -10
    echo ""
}

# Function to check if webhook receiver is ready
check_webhook_ready() {
    echo "🔍 Checking webhook receiver status..."
    kubectl get pods -n monitoring | grep webhook-receiver
    kubectl logs -n monitoring deployment/webhook-receiver --tail=3
    echo ""
}

# Step 1: Check webhook receiver
echo "Step 1: Verifying webhook receiver is ready"
check_webhook_ready

# Step 2: Test manual webhook call
echo "Step 2: Sending test webhook to verify it's working"
kubectl exec -n monitoring deployment/webhook-receiver -- curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"status":"firing","alerts":[{"labels":{"alertname":"TestManual"},"annotations":{"summary":"Manual test"}}]}' \
  http://localhost:8080/webhook

sleep 2
check_webhooks

# Step 3: Trigger real alert
echo "Step 3: Triggering real alert by scaling down test-app"
kubectl scale deployment test-app --replicas=0
echo "Waiting 30 seconds for alert to fire..."

# Monitor for webhooks
for i in {1..6}; do
    echo "Checking webhooks (attempt $i/6)..."
    check_webhooks
    sleep 10
done

# Step 4: Resolve alert
echo "Step 4: Resolving alert by scaling up test-app"
kubectl scale deployment test-app --replicas=1
echo "Waiting 30 seconds for alert to resolve..."

# Monitor for resolution webhooks
for i in {1..6}; do
    echo "Checking for resolution webhooks (attempt $i/6)..."
    check_webhooks
    sleep 10
done

echo ""
echo "🎯 Test complete! Check the logs above for webhook activity."
echo "If you see webhook activity, the self-resolution is working!"
echo ""
echo "To see real-time webhook monitoring, run:"
echo "kubectl logs -f -n monitoring deployment/webhook-receiver"
