#!/bin/bash
#
# Instance bootstrap. Runs once at first boot, as root, via cloud-init.
# Output is captured in /var/log/cloud-init-output.log — read that first when
# an instance comes up unhealthy.

set -euo pipefail

exec > >(tee /var/log/bootstrap.log | logger -t bootstrap -s 2>/dev/console) 2>&1
echo "=== Bootstrap starting at $(date -u) ==="

export DEBIAN_FRONTEND=noninteractive

# Cloud-init and unattended-upgrades can both hold the dpkg lock at first boot.
# Wait rather than racing them, or apt-get exits non-zero and set -e kills us.
for _ in $(seq 1 60); do
  if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for the dpkg lock to clear..."
  sleep 5
done

apt-get update -y
apt-get install -y nginx curl unzip

# ---------------------------------------------------------------------------
# Nginx
# ---------------------------------------------------------------------------

install -d -o www-data -g www-data /var/www/html

cat >/etc/nginx/sites-available/default <<'NGINXCONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    server_name _;

    # Serve /about for about.html so the URLs stay clean.
    location / {
        try_files $uri $uri.html $uri/ =404;
    }

    # The ALB polls this. Answering from nginx rather than a file means the
    # check fails if nginx itself is broken, which is exactly what we want.
    location = /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'ok';
    }

    # The deployment stamp must never be cached, or the footer shows a stale
    # deploy time after a rollout.
    location = /build-info.json {
        add_header Cache-Control "no-store, must-revalidate";
        expires -1;
    }

    location ~* \.(css|js|png|jpg|jpeg|svg|ico|woff2?)$ {
        expires 1h;
        add_header Cache-Control "public";
    }

    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;
    gzip_min_length 512;

    # Reduce the fingerprint available to an attacker enumerating versions.
    server_tokens off;
}
NGINXCONF

# A placeholder so the instance passes its health check the moment nginx is up,
# before the pipeline has deployed anything. Without this the ASG would cycle
# instances during the window between launch and first deploy.
if [ ! -f /var/www/html/index.html ]; then
  cat >/var/www/html/index.html <<'PLACEHOLDER'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Awaiting deployment</title></head>
<body>
  <h1>Instance provisioned</h1>
  <p>Nginx is serving. Awaiting the first deployment from the pipeline.</p>
</body>
</html>
PLACEHOLDER
  chown www-data:www-data /var/www/html/index.html
fi

nginx -t
systemctl enable nginx
systemctl restart nginx

# ---------------------------------------------------------------------------
# Deploy user
# ---------------------------------------------------------------------------
# The pipeline rsyncs into /var/www/html over SSH. Rather than hand it root,
# give the existing ubuntu user group ownership of the web root.

usermod -aG www-data ubuntu
chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html
# setgid keeps new files group-owned by www-data, so nginx can read whatever
# the deploy writes without a chown step in the pipeline.
find /var/www/html -type d -exec chmod g+s {} \;

%{ if enable_cloudwatch_agent ~}
# ---------------------------------------------------------------------------
# CloudWatch agent
# ---------------------------------------------------------------------------
# Memory and disk are invisible to the hypervisor, so CPU is the only default
# EC2 metric. The agent is what makes the memory alarm possible.

ARCH="$(dpkg --print-architecture)"
curl -fsSL -o /tmp/amazon-cloudwatch-agent.deb \
  "https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/$${ARCH}/latest/amazon-cloudwatch-agent.deb"
dpkg -i -E /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "${metrics_namespace}",
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "InstanceId": "$${aws:InstanceId}"
    },
    "aggregation_dimensions": [["AutoScalingGroupName"], []],
    "metrics_collected": {
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MemoryUtilization", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DiskUtilization", "unit": "Percent"}
        ],
        "resources": ["/"],
        "ignore_file_system_types": ["sysfs", "devtmpfs", "tmpfs", "overlay"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "${log_group_prefix}/nginx/access",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "${log_group_prefix}/nginx/error",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
CWCONF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

systemctl enable amazon-cloudwatch-agent
%{ endif ~}

# ---------------------------------------------------------------------------
# Hardening
# ---------------------------------------------------------------------------

# Password authentication is off by default on Ubuntu AMIs; assert it rather
# than assume it.
if [ -d /etc/ssh/sshd_config.d ]; then
  cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'SSHCONF'
PasswordAuthentication no
PermitRootLogin no
SSHCONF
  systemctl reload ssh || systemctl reload sshd || true
fi

echo "=== Bootstrap finished at $(date -u) ==="
