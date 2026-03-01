#!/bin/bash
set -e
# ============================================
# Step 1: Setup IAM Roles and Policies
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 1: Setting Up IAM Roles and Policies"
echo "=========================================="

# --- Create EC2 Trust Policy ---
echo "[1/6] Creating trust policy for EC2..."
cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# --- Create Custom EC2 Policy (Limited Access) ---
echo "[2/6] Creating custom EC2 policy with limited permissions..."
cat > /tmp/jafar-ec2-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeAutoScalingGroups",
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file:///tmp/jafar-ec2-policy.json \
  --region "$AWS_REGION" 2>/dev/null && echo "  Policy '$POLICY_NAME' created." || echo "  Policy already exists."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

# --- Create Admin Role ---
echo "[3/6] Creating admin role: $ADMIN_ROLE..."
aws iam create-role \
  --role-name "$ADMIN_ROLE" \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
  2>/dev/null && echo "  Role '$ADMIN_ROLE' created." || echo "  Role already exists."

aws iam attach-role-policy \
  --role-name "$ADMIN_ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
echo "  Attached EC2FullAccess to $ADMIN_ROLE"

# --- Create ReadOnly Role ---
echo "[4/6] Creating readonly role: $READONLY_ROLE..."
aws iam create-role \
  --role-name "$READONLY_ROLE" \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
  2>/dev/null && echo "  Role '$READONLY_ROLE' created." || echo "  Role already exists."

aws iam attach-role-policy \
  --role-name "$READONLY_ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
echo "  Attached EC2ReadOnlyAccess to $READONLY_ROLE"

# --- Create Instance Profile ---
echo "[5/6] Creating instance profile: $INSTANCE_PROFILE..."
aws iam create-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE" \
  2>/dev/null && echo "  Instance profile created." || echo "  Instance profile already exists."

aws iam add-role-to-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE" \
  --role-name "$ADMIN_ROLE" \
  2>/dev/null && echo "  Role added to instance profile." || echo "  Role already attached."

# --- Verify ---
echo "[6/6] Verifying IAM setup..."
echo "  Roles created:"
aws iam list-roles --query "Roles[?contains(RoleName, '$PREFIX')].RoleName" --output table
echo ""
echo "IAM setup complete!"
echo "  Admin Role: $ADMIN_ROLE (Full EC2 Access)"
echo "  ReadOnly Role: $READONLY_ROLE (Read-Only EC2 Access)"
echo "  Instance Profile: $INSTANCE_PROFILE"
