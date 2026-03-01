#!/bin/bash
# ============================================
# VCC Assignment 2 - Configuration File
# Name: Jafar Sadiq A | Roll No: M25AI2113
# ============================================

# AWS Region
export AWS_REGION="us-east-1"

# Naming Prefix
export PREFIX="jafar"

# EC2 Configuration
export INSTANCE_TYPE="t2.micro"
export AMI_ID="ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS in us-east-1
export KEY_NAME="${PREFIX}-key"

# Security Group
export SG_NAME="${PREFIX}-web-sg"

# Auto Scaling
export LAUNCH_TEMPLATE_NAME="${PREFIX}-launch-template"
export ASG_NAME="${PREFIX}-asg"
export ASG_MIN=1
export ASG_MAX=3
export ASG_DESIRED=1
export CPU_TARGET=50  # Scale out when CPU > 50%

# Load Balancer
export ALB_NAME="${PREFIX}-alb"
export TG_NAME="${PREFIX}-tg"

# IAM
export ADMIN_ROLE="${PREFIX}-admin-role"
export READONLY_ROLE="${PREFIX}-readonly-role"
export INSTANCE_PROFILE="${PREFIX}-ec2-profile"
export POLICY_NAME="${PREFIX}-ec2-policy"

# Replace with your IP for SSH access
export MY_IP="0.0.0.0/0"  # CHANGE THIS to your actual IP like "203.0.113.5/32"

echo "Configuration loaded for: $PREFIX"
echo "Region: $AWS_REGION"
echo "Instance Type: $INSTANCE_TYPE"
