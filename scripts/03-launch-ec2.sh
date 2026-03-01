#!/bin/bash
set -e
# ============================================
# Step 3: Launch EC2 Instance
# VCC Assignment 2 - Jafar Sadiq A (M25AI2113)
# ============================================

source "$(dirname "$0")/config.sh"

echo "=========================================="
echo "Step 3: Launching EC2 Instance"
echo "=========================================="

# --- Create Key Pair ---
echo "[1/5] Creating key pair: $KEY_NAME..."
aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --query "KeyMaterial" \
  --output text \
  --region "$AWS_REGION" > "${KEY_NAME}.pem" 2>/dev/null && {
    chmod 400 "${KEY_NAME}.pem"
    echo "  Key pair created and saved to ${KEY_NAME}.pem"
  } || echo "  Key pair already exists"

# --- Get Security Group ID ---
echo "[2/5] Getting security group ID..."
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region "$AWS_REGION")
echo "  Security Group: $SG_ID"

# --- Create User Data Script (Nginx Setup) ---
echo "[3/5] Preparing user data script (Nginx installation)..."
cat > /tmp/jafar-userdata.sh << 'USERDATA'
#!/bin/bash
apt-get update -y
apt-get install -y nginx stress

# Create custom homepage
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=$(hostname)
cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head><title>Jafar - VCC Assignment 2</title></head>
<body style="font-family: Arial; text-align: center; padding: 50px;">
  <h1>VCC Assignment 2 - Auto Scaling Demo</h1>
  <h2>Jafar Sadiq A (M25AI2113)</h2>
  <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
  <p><strong>Hostname:</strong> $HOSTNAME</p>
  <p>Server: Nginx on Ubuntu 22.04</p>
</body>
</html>
HTML

systemctl enable nginx
systemctl restart nginx
USERDATA

# --- Launch EC2 Instance ---
echo "[4/5] Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --user-data file:///tmp/jafar-userdata.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-web-server}]" \
  --region "$AWS_REGION" \
  --query "Instances[0].InstanceId" \
  --output text)
echo "  Instance launched: $INSTANCE_ID"

# --- Wait for Instance to be Running ---
echo "[5/5] Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text \
  --region "$AWS_REGION")

echo ""
echo "EC2 Instance launched successfully!"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo "  SSH: ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
echo "  Web: http://${PUBLIC_IP}"
echo ""
echo "Wait 2-3 minutes for Nginx to install, then visit the web URL."
