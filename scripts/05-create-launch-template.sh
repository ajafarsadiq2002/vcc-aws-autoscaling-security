#!/bin/bash
set -e
# ============================================
# Step 5: Create Launch Template
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 5: Creating Launch Template"
echo "=========================================="

# --- Get AMI ID ---
echo "[1/3] Getting AMI ID..."
CUSTOM_AMI=$(aws ec2 describe-images \
  --filters "Name=name,Values=${PREFIX}-web-ami" \
  --query "Images[0].ImageId" \
  --output text \
  --region "$AWS_REGION")
echo "  AMI: $CUSTOM_AMI"

# --- Get Security Group ID ---
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$AWS_REGION")
echo "  Security Group: $SG_ID"

# --- Create User Data (base64 encoded) ---
echo "[2/3] Preparing user data..."
USER_DATA=$(cat << 'USERDATA' | base64 -w 0
#!/bin/bash
systemctl enable nginx
systemctl start nginx
USERDATA
)

# --- Create Launch Template ---
echo "[3/3] Creating launch template: $LAUNCH_TEMPLATE_NAME..."
LT_ID=$(aws ec2 create-launch-template \
  --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
  --version-description "Jafar VCC Assignment 2 - Nginx Web Server" \
  --launch-template-data "{
    \"ImageId\": \"$CUSTOM_AMI\",
    \"InstanceType\": \"$INSTANCE_TYPE\",
    \"KeyName\": \"$KEY_NAME\",
    \"SecurityGroupIds\": [\"$SG_ID\"],
    \"UserData\": \"$USER_DATA\",
    \"TagSpecifications\": [{
      \"ResourceType\": \"instance\",
      \"Tags\": [{\"Key\": \"Name\", \"Value\": \"${PREFIX}-asg-instance\"}]
    }]
  }" \
  --region "$AWS_REGION" \
  --query "LaunchTemplate.LaunchTemplateId" \
  --output text)

echo ""
echo "Launch Template created successfully!"
echo "  Template ID: $LT_ID"
echo "  Template Name: $LAUNCH_TEMPLATE_NAME"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  AMI: $CUSTOM_AMI"
