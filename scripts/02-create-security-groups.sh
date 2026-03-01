#!/bin/bash
set -e
# ============================================
# Step 2: Create Security Groups (Firewall)
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 2: Configuring Security Groups"
echo "=========================================="

# --- Get Default VPC ID ---
echo "[1/4] Getting default VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region "$AWS_REGION")
echo "  Default VPC: $VPC_ID"

# --- Create Security Group ---
echo "[2/4] Creating security group: $SG_NAME..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Jafar VCC Assignment 2 - Web Server Security Group" \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION" \
  --query "GroupId" \
  --output text 2>/dev/null) && echo "  Security Group created: $SG_ID" || {
    SG_ID=$(aws ec2 describe-security-groups \
      --filters "Name=group-name,Values=$SG_NAME" \
      --query "SecurityGroups[0].GroupId" \
      --output text \
      --region "$AWS_REGION")
    echo "  Security Group already exists: $SG_ID"
  }

# --- Add Inbound Rules ---
echo "[3/4] Adding inbound firewall rules..."

# Rule 1: Allow HTTP (port 80) from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr "0.0.0.0/0" \
  --region "$AWS_REGION" 2>/dev/null && echo "  ALLOW: HTTP (80) from 0.0.0.0/0" || echo "  HTTP rule already exists"

# Rule 2: Allow SSH (port 22) - restricted to your IP
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "$MY_IP" \
  --region "$AWS_REGION" 2>/dev/null && echo "  ALLOW: SSH (22) from $MY_IP" || echo "  SSH rule already exists"

# Note: Outbound (egress) allows all traffic by default in AWS

# --- Verify ---
echo "[4/4] Verifying security group rules..."
echo ""
echo "Inbound Rules:"
aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].IpPermissions" \
  --output table \
  --region "$AWS_REGION"

echo ""
echo "Security Group setup complete!"
echo "  SG ID: $SG_ID"
echo "  SG Name: $SG_NAME"
echo ""
echo "Save this SG_ID for later: $SG_ID"
