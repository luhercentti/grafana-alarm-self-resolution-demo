#!/bin/bash

# Real-time webhook monitoring script
echo "🔍 REAL-TIME WEBHOOK MONITORING"
echo "==============================="
echo "This script will monitor webhook activity in real-time"
echo "Press Ctrl+C to stop"
echo ""

# Start monitoring webhook logs in background
kubectl logs -f -n monitoring deployment/webhook-receiver &
WEBHOOK_LOG_PID=$!

# Start monitoring Alertmanager logs in background  
kubectl logs -f -n monitoring alertmanager-prometheus-stack-kube-prom-alertmanager-0 -c alertmanager | grep -i webhook &
AM_LOG_PID=$!

echo "Monitoring started. You can now:"
echo "1. Scale down test app: kubectl scale deployment test-app --replicas=0"
echo "2. Wait for alert to fire (30-60 seconds)"
echo "3. Scale up test app: kubectl scale deployment test-app --replicas=1"
echo "4. Watch for resolution webhook"
echo ""
echo "Current test-app status:"
kubectl get deployment test-app

# Wait for user interrupt
trap 'echo ""; echo "Stopping monitoring..."; kill $WEBHOOK_LOG_PID $AM_LOG_PID 2>/dev/null; exit 0' INT

# Keep script running
while true; do
    sleep 5
done
