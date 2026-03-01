#!/bin/bash
set -e
# ============================================
# Step 7: Create Auto Scaling Group
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 7: Setting Up Auto Scaling Group"
echo "=========================================="

# --- Get Required ARNs ---
echo "[1/3] Getting required resource information..."
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --region "$AWS_REGION")
echo "  Target Group: $TG_ARN"

# Get availability zones
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region "$AWS_REGION")

AZS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].AvailabilityZone" \
  --output text \
  --region "$AWS_REGION")
echo "  Availability Zones: $AZS"

# --- Create Auto Scaling Group ---
echo "[2/3] Creating Auto Scaling Group: $ASG_NAME..."
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --launch-template "LaunchTemplateName=$LAUNCH_TEMPLATE_NAME,Version=\$Latest" \
  --min-size $ASG_MIN \
  --max-size $ASG_MAX \
  --desired-capacity $ASG_DESIRED \
  --target-group-arns "$TG_ARN" \
  --availability-zones $AZS \
  --health-check-type ELB \
  --health-check-grace-period 120 \
  --default-cooldown 60 \
  --region "$AWS_REGION"
echo "  ASG created: Min=$ASG_MIN, Max=$ASG_MAX, Desired=$ASG_DESIRED"

# --- Create Target Tracking Scaling Policy ---
echo "[3/3] Creating scaling policy: CPU Target Tracking at ${CPU_TARGET}%..."
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name "${PREFIX}-cpu-target-tracking" \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration "{
    \"PredefinedMetricSpecification\": {
      \"PredefinedMetricType\": \"ASGAverageCPUUtilization\"
    },
    \"TargetValue\": $CPU_TARGET,
    \"DisableScaleIn\": false
  }" \
  --region "$AWS_REGION"

echo ""
echo "Auto Scaling Group setup complete!"
echo "  ASG Name: $ASG_NAME"
echo "  Scaling Policy: Target Tracking (CPU > ${CPU_TARGET}%)"
echo "  Min Instances: $ASG_MIN"
echo "  Max Instances: $ASG_MAX"
echo ""
echo "The ASG will automatically:"
echo "  - Scale OUT when CPU > ${CPU_TARGET}%"
echo "  - Scale IN when CPU drops below ${CPU_TARGET}%"
