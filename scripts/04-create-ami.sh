#!/bin/bash
set -e
# ============================================
# Step 4: Create AMI from EC2 Instance
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 4: Creating AMI (Amazon Machine Image)"
echo "=========================================="

# --- Get Instance ID ---
echo "[1/3] Getting running instance ID..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PREFIX}-web-server" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --region "$AWS_REGION")
echo "  Instance: $INSTANCE_ID"

# --- Create AMI ---
echo "[2/3] Creating AMI: ${PREFIX}-web-ami..."
AMI_ID=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "${PREFIX}-web-ami" \
  --description "Jafar VCC Assignment 2 - Nginx Web Server AMI" \
  --no-reboot \
  --region "$AWS_REGION" \
  --query "ImageId" \
  --output text)
echo "  AMI creation started: $AMI_ID"

# --- Wait for AMI ---
echo "[3/3] Waiting for AMI to become available (this may take 2-5 minutes)..."
aws ec2 wait image-available \
  --image-ids "$AMI_ID" \
  --region "$AWS_REGION"

echo ""
echo "AMI created successfully!"
echo "  AMI ID: $AMI_ID"
echo "  AMI Name: ${PREFIX}-web-ami"
echo ""
echo "Save this AMI_ID for the launch template: $AMI_ID"
