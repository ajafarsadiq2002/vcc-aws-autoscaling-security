# VCC Assignment 2 — Auto Scaling & Security on AWS

**Name:** Jafar Sadiq A

**Roll No:** M25AI2113

**Course:** Virtualization and Cloud Computing

---

## Overview

Fully automated AWS infrastructure that deploys a Nginx web server with auto-scaling based on CPU utilization. The system automatically adds EC2 instances when traffic spikes and removes them when load drops — all secured with IAM roles and Security Groups.

## Architecture

```
                    Users
                      │
                      ▼
             ┌─────────────────┐
             │  Load Balancer   │
             │   (jafar-alb)    │
             └───────┬─────────┘
                     │
        ┌────────────▼─────────────┐
        │   Auto Scaling Group     │
        │   Min: 1 | Max: 3       │
        │   Target: CPU 50%       │
        │                          │
        │  ┌──────┐ ┌──────┐ ┌──────┐
        │  │ EC2  │ │ EC2  │ │ EC2  │
        │  │Nginx │ │Nginx │ │Nginx │
        │  └──────┘ └──────┘ └──────┘
        └──────────────────────────┘
               │              │
      ┌────────▼─────┐  ┌────▼──────────┐
      │ Security     │  │ IAM Roles     │
      │ Group        │  │               │
      │ HTTP: 80 ✓   │  │ Admin: Full   │
      │ SSH: 22 🔒   │  │ ReadOnly: View│
      └──────────────┘  └───────────────┘
               │
      ┌────────▼──────────┐
      │ CloudWatch        │
      │ Monitors CPU      │
      │ Triggers scaling  │
      └───────────────────┘
```

## Tech Stack

| Component | Choice |
|-----------|--------|
| Cloud | AWS Free Tier (us-east-1) |
| OS | Ubuntu 22.04 LTS |
| Web Server | Nginx |
| Instance | t2.micro (1 vCPU, 1 GB) |
| Scaling | Target Tracking — CPU 50% |
| Load Balancer | Application LB (Layer 7) |
| Security | IAM Roles + Security Groups |
| Execution | AWS CloudShell |

## Scripts

All infrastructure is deployed through 9 Bash scripts executed in order via AWS CloudShell.

| Script | Purpose |
|--------|---------|
| `config.sh` | Shared variables — region, prefix, thresholds |
| `01-setup-iam.sh` | IAM roles (admin + readonly), custom policy, instance profile |
| `02-create-security-groups.sh` | Security group — HTTP (80), SSH (22) |
| `03-launch-ec2.sh` | EC2 instance with Nginx user data script |
| `04-create-ami.sh` | AMI snapshot of configured server |
| `05-create-launch-template.sh` | Launch template for ASG (AMI + config) |
| `06-create-alb.sh` | ALB + target group + HTTP listener |
| `07-create-asg.sh` | Auto Scaling Group + target tracking policy |
| `08-stress-test.sh` | Stress test instructions + monitoring commands |
| `09-cleanup.sh` | Deletes all resources in dependency order |

## Quick Start

```bash
# Upload all .sh files to AWS CloudShell (Actions → Upload file)

# Make executable
chmod +x *.sh

# Deploy in order
bash 01-setup-iam.sh
bash 02-create-security-groups.sh
bash 03-launch-ec2.sh
bash 04-create-ami.sh              # ~3-5 min wait
bash 05-create-launch-template.sh
bash 06-create-alb.sh              # ~2-3 min wait
bash 07-create-asg.sh

# Stress test (run in EC2 Instance Connect, username: ubuntu)
stress --cpu 4 --timeout 300

# Monitor scaling
aws cloudwatch describe-alarms \
  --alarm-name-prefix "TargetTracking-jafar-asg" \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue}' \
  --output table --region us-east-1

# CLEANUP (run after demo!)
bash 09-cleanup.sh
```

## How Auto Scaling Works

1. **Normal** — 1 instance runs, serves traffic through ALB
2. **High load** — CPU crosses 50%, CloudWatch AlarmHigh triggers, ASG launches more instances (up to 3)
3. **Load drops** — CPU falls back, CloudWatch AlarmLow triggers, ASG terminates extra instances
4. **Cooldown** — 60s wait between scaling actions to prevent thrashing

## Security

**Network layer (Security Group):**
- Port 80 (HTTP) — open to `0.0.0.0/0` (public web)
- Port 22 (SSH) — restricted to admin IP (`/32`)
- All other inbound — denied by default

**Access layer (IAM):**
- `jafar-admin-role` — AmazonEC2FullAccess (infrastructure management)
- `jafar-readonly-role` — AmazonEC2ReadOnlyAccess (monitoring only)
- `jafar-ec2-policy` — Custom: DescribeInstances, StartInstances, StopInstances
- Instance profile with temporary credentials (no hardcoded keys)

## Project Structure

```
├── diagrams/
│   └── m25ai2113_vcc_assignment_2_Arch.jpg
├── scripts/
│   ├── config.sh
│   ├── 01-setup-iam.sh
│   ├── 02-create-security-groups.sh
│   ├── 03-launch-ec2.sh
│   ├── 04-create-ami.sh
│   ├── 05-create-launch-template.sh
│   ├── 06-create-alb.sh
│   ├── 07-create-asg.sh
│   ├── 08-stress-test.sh
│   └── 09-cleanup.sh
└── README.md
```

## Free Tier Safety

- All instances: `t2.micro` (750 hrs/month free)
- Estimated usage: ~5-10 hours total
- **Always run `09-cleanup.sh` after demo to avoid charges**

## License

Academic project — IIT Jodhpur, M.Tech AI, 2026.
