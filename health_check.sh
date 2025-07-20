#!/bin/bash

# Quick verification script

echo "=== MONITORING STACK HEALTH CHECK ==="

# 1. Check if monitoring namespace exists
if kubectl get namespace monitoring >/dev/null 2>&1; then
    echo "✅ Monitoring namespace exists"
else
    echo "❌ Monitoring namespace missing"
    exit 1
fi

# 2. Check pods status
echo ""
echo "📊 Pod Status:"
kubectl get pods -n monitoring

# 3. Count ready pods
TOTAL_PODS=$(kubectl get pods -n monitoring --no-headers | wc -l)
READY_PODS=$(kubectl get pods -n monitoring --no-headers | grep "1/1\|2/2\|3/3" | wc -l)

echo ""
echo "Pod Summary: $READY_PODS/$TOTAL_PODS pods ready"

# 4. Get actual service names
echo ""
echo "🔍 Available Services:"
kubectl get svc -n monitoring

# 5. Find the correct service names and store them
GRAFANA_SVC=$(kubectl get svc -n monitoring -o name | grep grafana | cut -d/ -f2)
PROMETHEUS_SVC=$(kubectl get svc -n monitoring -o name | grep "prometheus.*prometheus" | grep -v operated | cut -d/ -f2 | head -1)
ALERTMANAGER_SVC=$(kubectl get svc -n monitoring -o name | grep alertmanager | grep -v operated | cut -d/ -f2)

echo ""
echo "🎯 Detected Services:"
echo "Grafana: $GRAFANA_SVC"
echo "Prometheus: $PROMETHEUS_SVC"
echo "Alertmanager: $ALERTMANAGER_SVC"

# 6. Test connectivity
echo ""
echo "🔗 Testing Connectivity:"

if [ ! -z "$GRAFANA_SVC" ]; then
    echo "Starting port-forward for Grafana..."
    kubectl port-forward -n monitoring svc/$GRAFANA_SVC 3000:80 >/dev/null 2>&1 &
    GRAFANA_PID=$!
    sleep 2
    if curl -s http://localhost:3000/api/health >/dev/null; then
        echo "✅ Grafana is accessible at http://localhost:3000"
        echo "   Username: admin, Password: admin123"
    else
        echo "❌ Grafana not responding"
    fi
    kill $GRAFANA_PID 2>/dev/null
else
    echo "❌ Grafana service not found"
fi

if [ ! -z "$PROMETHEUS_SVC" ]; then
    kubectl port-forward -n monitoring svc/$PROMETHEUS_SVC 9090:9090 >/dev/null 2>&1 &
    PROM_PID=$!
    sleep 2
    if curl -s http://localhost:9090/-/ready >/dev/null; then
        echo "✅ Prometheus is accessible at http://localhost:9090"
    else
        echo "❌ Prometheus not responding"
    fi
    kill $PROM_PID 2>/dev/null
else
    echo "❌ Prometheus service not found"
fi

if [ ! -z "$ALERTMANAGER_SVC" ]; then
    kubectl port-forward -n monitoring svc/$ALERTMANAGER_SVC 9093:9093 >/dev/null 2>&1 &
    AM_PID=$!
    sleep 2
    if curl -s http://localhost:9093/-/ready >/dev/null; then
        echo "✅ Alertmanager is accessible at http://localhost:9093"
    else
        echo "❌ Alertmanager not responding"
    fi
    kill $AM_PID 2>/dev/null
else
    echo "❌ Alertmanager service not found"
fi

echo ""
echo "=== NEXT STEPS ==="
echo "If all services are working:"
echo "1. Access Grafana: kubectl port-forward -n monitoring svc/$GRAFANA_SVC 3000:80"
echo "2. Access Prometheus: kubectl port-forward -n monitoring svc/$PROMETHEUS_SVC 9090:9090"
echo "3. Access Alertmanager: kubectl port-forward -n monitoring svc/$ALERTMANAGER_SVC 9093:9093"
echo ""
echo "If some services are not working:"
echo "1. Check pod logs: kubectl logs -n monitoring [POD_NAME]"
echo "2. Check pod descriptions: kubectl describe pod -n monitoring [POD_NAME]"
echo "3. Restart the helm installation if needed"

echo ""
echo "=== SIMPLE ALERTING TEST ==="
echo "Once services are working, you can test alerts with:"
echo "1. Deploy test app: kubectl apply -f test-app.yaml"
echo "2. Scale down: kubectl scale deployment test-app --replicas=0"
echo "3. Check alerts in Grafana or Prometheus"
echo "4. Scale up: kubectl scale deployment test-app --replicas=1"
echo "5. Verify alert resolves"