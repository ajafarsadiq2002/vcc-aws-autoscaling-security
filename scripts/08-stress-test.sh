#!/bin/bash
set -e
# ============================================
# Step 8: Stress Test to Trigger Auto Scaling
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 8: Stress Testing & Monitoring"
echo "=========================================="

# --- Get Instance Info ---
echo "[1/4] Getting instance information..."
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[0].InstanceId" \
  --output text \
  --region "$AWS_REGION")

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text \
  --region "$AWS_REGION")

echo "  Instance: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"

# --- SSH and Run Stress Test ---
echo "[2/4] Running stress test on instance..."
echo ""
echo "  Run this command to SSH and stress test:"
echo "  ─────────────────────────────────────────"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo "  sudo apt-get install -y stress"
echo "  stress --cpu 4 --timeout 300"
echo "  ─────────────────────────────────────────"
echo ""
echo "  Or run remotely:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP} 'sudo apt-get install -y stress && stress --cpu 4 --timeout 300'"
echo ""

# --- Monitor Auto Scaling Activity ---
echo "[3/4] Monitoring ASG activity (check every 30s)..."
echo "  Run this in another terminal to monitor:"
echo "  ─────────────────────────────────────────"
echo "  # Watch ASG scaling activities"
echo "  watch -n 30 'aws autoscaling describe-scaling-activities \\"
echo "    --auto-scaling-group-name $ASG_NAME \\"
echo "    --query \"Activities[*].[StatusCode,Description]\" \\"
echo "    --output table --region $AWS_REGION'"
echo ""
echo "  # Watch instance count"
echo "  watch -n 30 'aws autoscaling describe-auto-scaling-groups \\"
echo "    --auto-scaling-group-names $ASG_NAME \\"
echo "    --query \"AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].InstanceId]\" \\"
echo "    --output table --region $AWS_REGION'"
echo "  ─────────────────────────────────────────"

# --- CloudWatch CPU Metrics ---
echo "[4/4] CloudWatch monitoring commands:"
echo "  ─────────────────────────────────────────"
echo "  # Get CPU utilization"
echo "  aws cloudwatch get-metric-statistics \\"
echo "    --namespace AWS/EC2 \\"
echo "    --metric-name CPUUtilization \\"
echo "    --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \\"
echo "    --start-time \$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \\"
echo "    --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \\"
echo "    --period 300 \\"
echo "    --statistics Average \\"
echo "    --region $AWS_REGION"
echo "  ─────────────────────────────────────────"
echo ""
echo "Expected behavior:"
echo "  1. CPU spikes above ${CPU_TARGET}%"
echo "  2. CloudWatch triggers scaling alarm"
echo "  3. ASG launches new instances (up to $ASG_MAX)"
echo "  4. After stress ends, CPU drops"
echo "  5. ASG terminates extra instances (back to $ASG_DESIRED)"
