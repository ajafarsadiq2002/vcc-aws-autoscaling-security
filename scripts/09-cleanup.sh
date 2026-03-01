#!/bin/bash
# ============================================
# Step 9: CLEANUP - Delete All Resources
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# IMPORTANT: Run this after demo to avoid charges!
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "  CLEANUP: Deleting All AWS Resources"
echo "=========================================="
echo ""
echo "WARNING: This will delete ALL resources created for this assignment."
echo ""
read -p "Are you sure? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# --- Step 1: Delete Auto Scaling Group ---
echo "[1/8] Deleting Auto Scaling Group: $ASG_NAME..."
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --min-size 0 --desired-capacity 0 \
  --region "$AWS_REGION" 2>/dev/null || true
sleep 10
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --force-delete \
  --region "$AWS_REGION" 2>/dev/null && echo "  ASG deleted." || echo "  ASG not found."

# --- Step 2: Delete Load Balancer ---
echo "[2/8] Deleting Load Balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null) || true

if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  # Delete listeners first
  LISTENERS=$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[*].ListenerArn" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null) || true
  for L in $LISTENERS; do
    aws elbv2 delete-listener --listener-arn "$L" --region "$AWS_REGION" 2>/dev/null || true
  done
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" 2>/dev/null || true
  echo "  ALB deleted."
else
  echo "  ALB not found."
fi

# Delete Target Group
echo "  Deleting target group..."
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null) || true
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  sleep 5
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region "$AWS_REGION" 2>/dev/null || true
  echo "  Target group deleted."
fi

# --- Step 3: Delete Launch Template ---
echo "[3/8] Deleting Launch Template: $LAUNCH_TEMPLATE_NAME..."
aws ec2 delete-launch-template \
  --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
  --region "$AWS_REGION" 2>/dev/null && echo "  Launch template deleted." || echo "  Not found."

# --- Step 4: Deregister AMI and Delete Snapshots ---
echo "[4/8] Deregistering AMI..."
AMI_ID=$(aws ec2 describe-images \
  --filters "Name=name,Values=${PREFIX}-web-ami" \
  --query "Images[0].ImageId" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null) || true
if [ -n "$AMI_ID" ] && [ "$AMI_ID" != "None" ]; then
  SNAP_IDS=$(aws ec2 describe-images \
    --image-ids "$AMI_ID" \
    --query "Images[0].BlockDeviceMappings[*].Ebs.SnapshotId" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null) || true
  aws ec2 deregister-image --image-id "$AMI_ID" --region "$AWS_REGION" 2>/dev/null || true
  echo "  AMI deregistered: $AMI_ID"
  for S in $SNAP_IDS; do
    aws ec2 delete-snapshot --snapshot-id "$S" --region "$AWS_REGION" 2>/dev/null || true
    echo "  Snapshot deleted: $S"
  done
fi

# --- Step 5: Terminate EC2 Instances ---
echo "[5/8] Terminating EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PREFIX}*" "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null) || true
if [ -n "$INSTANCES" ]; then
  aws ec2 terminate-instances --instance-ids $INSTANCES --region "$AWS_REGION" 2>/dev/null || true
  echo "  Terminated: $INSTANCES"
else
  echo "  No instances found."
fi

# --- Step 6: Delete Security Group ---
echo "[6/8] Deleting Security Group: $SG_NAME..."
sleep 5
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null) || true
if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
  aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION" 2>/dev/null && echo "  SG deleted." || echo "  SG in use, may need to wait and retry."
fi

# --- Step 7: Delete Key Pair ---
echo "[7/8] Deleting Key Pair: $KEY_NAME..."
aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$AWS_REGION" 2>/dev/null && echo "  Key pair deleted." || echo "  Not found."
rm -f "${KEY_NAME}.pem" 2>/dev/null || true

# --- Step 8: Delete IAM Resources ---
echo "[8/8] Cleaning up IAM resources..."
# Remove role from instance profile
aws iam remove-role-from-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE" \
  --role-name "$ADMIN_ROLE" 2>/dev/null || true
aws iam delete-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE" 2>/dev/null && echo "  Instance profile deleted." || true

# Detach and delete admin role
aws iam detach-role-policy \
  --role-name "$ADMIN_ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" 2>/dev/null || true
aws iam delete-role --role-name "$ADMIN_ROLE" 2>/dev/null && echo "  Admin role deleted." || true

# Detach and delete readonly role
aws iam detach-role-policy \
  --role-name "$READONLY_ROLE" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess" 2>/dev/null || true
aws iam delete-role --role-name "$READONLY_ROLE" 2>/dev/null && echo "  ReadOnly role deleted." || true

# Delete custom policy
aws iam delete-policy \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" 2>/dev/null && echo "  Custom policy deleted." || true

echo ""
echo "=========================================="
echo "  CLEANUP COMPLETE!"
echo "=========================================="
echo ""
echo "Verify in AWS Console:"
echo "  - EC2 > Instances (should be empty)"
echo "  - EC2 > Load Balancers (should be empty)"
echo "  - EC2 > Auto Scaling Groups (should be empty)"
echo "  - IAM > Roles (jafar-* roles removed)"
