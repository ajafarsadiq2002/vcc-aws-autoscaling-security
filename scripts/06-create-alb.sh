#!/bin/bash
set -e
# ============================================
# Step 6: Create Application Load Balancer
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 6: Setting Up Application Load Balancer"
echo "=========================================="

# --- Get VPC and Subnets ---
echo "[1/4] Getting VPC and subnet information..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region "$AWS_REGION")
echo "  VPC: $VPC_ID"

SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region "$AWS_REGION")
echo "  Subnets: $SUBNETS"

# --- Get Security Group ---
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$AWS_REGION")

# --- Create Target Group ---
echo "[2/4] Creating target group: $TG_NAME..."
TG_ARN=$(aws elbv2 create-target-group \
  --name "$TG_NAME" \
  --protocol HTTP \
  --port 80 \
  --vpc-id "$VPC_ID" \
  --health-check-protocol HTTP \
  --health-check-path "/" \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --region "$AWS_REGION" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)
echo "  Target Group ARN: $TG_ARN"

# --- Create ALB ---
echo "[3/4] Creating Application Load Balancer: $ALB_NAME..."
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name "$ALB_NAME" \
  --subnets $SUBNETS \
  --security-groups "$SG_ID" \
  --scheme internet-facing \
  --type application \
  --region "$AWS_REGION" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text)
echo "  ALB ARN: $ALB_ARN"

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" \
  --output text \
  --region "$AWS_REGION")

# --- Create Listener ---
echo "[4/4] Creating listener (HTTP:80)..."
LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
  --region "$AWS_REGION" \
  --query "Listeners[0].ListenerArn" \
  --output text)
echo "  Listener ARN: $LISTENER_ARN"

echo ""
echo "Load Balancer setup complete!"
echo "  ALB DNS: http://$ALB_DNS"
echo "  Target Group: $TG_NAME"
echo ""
echo "Note: ALB may take 2-3 minutes to become active."
