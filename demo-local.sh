#!/bin/bash

# Local Minikube Alert Self-Resolution Demo
echo "🏠 LOCAL MINIKUBE ALERT SELF-RESOLUTION DEMO"
echo "============================================="
echo ""
echo "✅ This lab simulates your EKS + JSM/JIRA scenario locally:"
echo ""
echo "🎭 ROLE MAPPING:"
echo "   Minikube cluster     = Your EKS cluster"
echo "   Webhook receiver     = Your JSM/JIRA system"
echo "   Test-app service     = Your production applications"
echo "   Prometheus alerts    = Your Grafana alerts"
echo ""
echo "🔄 WORKFLOW SIMULATION:"
echo "   1. App goes down     → Alert fires     → JSM ticket CREATED"
echo "   2. App comes back up → Alert resolves  → JSM ticket CLOSED"
echo ""

# Check current status
echo "📊 CURRENT STATUS:"
echo "Minikube context: $(kubectl config current-context)"
echo "Test app status: $(kubectl get deployment test-app --no-headers 2>/dev/null || echo 'Not deployed')"
echo ""

# Function to show webhook activity (simulating JSM ticket activity)
show_jsm_simulation() {
    echo "🎫 SIMULATED JSM/JIRA ACTIVITY:"
    echo "Looking for recent webhook calls (these would be JSM API calls in production)..."
    
    # Get recent webhook logs
    RECENT_LOGS=$(kubectl logs --tail=50 -n monitoring deployment/webhook-receiver 2>/dev/null | grep -E "(WEBHOOK RECEIVED|ALERT FIRING|ALERT RESOLVED|Alert:|Status:)" | tail -10)
    
    if [ -z "$RECENT_LOGS" ]; then
        echo "No recent webhook activity (no JSM tickets created/closed)"
    else
        echo "$RECENT_LOGS" | while read line; do
            if [[ $line == *"ALERT FIRING"* ]]; then
                echo "🔥 $line → Would CREATE JSM ticket"
            elif [[ $line == *"ALERT RESOLVED"* ]]; then
                echo "✅ $line → Would CLOSE JSM ticket"
            else
                echo "📋 $line"
            fi
        done
    fi
    echo ""
}

echo "🚀 STARTING LIVE DEMONSTRATION:"
echo ""

# Step 1: Show initial state
echo "Step 1: Initial state (everything healthy)"
show_jsm_simulation

# Step 2: Trigger the alert (simulate app failure)
echo "Step 2: Simulating application failure..."
echo "Command: kubectl scale deployment test-app --replicas=0"
kubectl scale deployment test-app --replicas=0
echo "✅ Test app scaled down (simulating your EKS app going down)"
echo "⏳ Waiting 45 seconds for alert to fire..."
sleep 45

show_jsm_simulation

# Step 3: Resolve the issue (simulate app recovery)  
echo "Step 3: Simulating application recovery..."
echo "Command: kubectl scale deployment test-app --replicas=1"
kubectl scale deployment test-app --replicas=1
echo "✅ Test app scaled up (simulating your EKS app recovery)"
echo "⏳ Waiting 45 seconds for alert to resolve..."
sleep 45

show_jsm_simulation

echo "🎯 DEMONSTRATION COMPLETE!"
echo ""
echo "💡 WHAT YOU JUST SAW:"
echo "   • Alert fired when app went down (would create JSM ticket)"
echo "   • Alert resolved when app came back up (would close JSM ticket)"
echo "   • This is EXACTLY what will happen in your EKS environment"
echo ""
echo "🔧 TO IMPLEMENT IN YOUR EKS + JSM SETUP:"
echo "   1. Replace webhook URL with your actual JSM webhook endpoint"
echo "   2. Add JSM authentication credentials"
echo "   3. Modify payload format to match JSM API"
echo "   4. Deploy this alertmanager config to your EKS cluster"
echo ""
echo "📋 VIEW REAL-TIME ACTIVITY:"
echo "   kubectl logs -f -n monitoring deployment/webhook-receiver"
echo ""
echo "🌐 ACCESS UIs LOCALLY:"
echo "   Grafana:      kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
echo "   Prometheus:   kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"
echo "   Alertmanager: kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-alertmanager 9093:9093"
