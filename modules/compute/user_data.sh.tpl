#!/usr/bin/env bash
# ============================================================
# EC2 User Data — bootstraps the application on instance launch
# Variables injected by Terraform templatefile()
# ============================================================
set -euo pipefail

APP_NAME="${app_name}"
APP_VERSION="${app_version}"
ENVIRONMENT="${environment}"
S3_BUCKET="${s3_bucket}"

# ---------- System updates ----------
yum update -y
yum install -y amazon-cloudwatch-agent jq curl

# ---------- CloudWatch Agent ----------
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app.log",
            "log_group_name": "/ec2/$${APP_NAME}/$${ENVIRONMENT}/app",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "AutoScalingGroupName": "\$${aws:AutoScalingGroupName}",
      "InstanceId": "\$${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"] }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# ---------- Pull app config from S3 ----------
aws s3 cp "s3://$${S3_BUCKET}/config/$${ENVIRONMENT}/app.env" /etc/app.env || true

# ---------- Application (example: systemd service) ----------
cat > /etc/systemd/system/app.service <<EOF
[Unit]
Description=$${APP_NAME} application
After=network.target

[Service]
Type=simple
EnvironmentFile=-/etc/app.env
Environment=APP_VERSION=$${APP_VERSION}
Environment=ENVIRONMENT=$${ENVIRONMENT}
ExecStart=/usr/local/bin/app
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/app.log
StandardError=append:/var/log/app.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app.service
# systemctl start app.service  # Uncomment when binary is present

echo "Bootstrap complete for $${APP_NAME} v$${APP_VERSION} in $${ENVIRONMENT}"
