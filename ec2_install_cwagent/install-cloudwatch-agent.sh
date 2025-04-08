#!/bin/bash

# CloudWatch Agent Installation and Configuration Script
# This script installs and configures the CloudWatch agent on EC2 instances
# Supports both x86_64 and ARM64 architectures
# Supports Amazon Linux, RHEL, Ubuntu, and Debian

set -e

echo "=== CloudWatch Agent Installation Script ==="
echo "Starting installation process..."

# Determine OS type
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
else
    echo "Cannot determine OS type. Exiting."
    exit 1
fi

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    ARCH_TYPE="amd64"
    RPM_ARCH="x86_64"
elif [ "$ARCH" == "aarch64" ]; then
    ARCH_TYPE="arm64"
    RPM_ARCH="arm64"
else
    echo "Unsupported architecture: $ARCH. Exiting."
    exit 1
fi

echo "Detected OS: $OS $VERSION"
echo "Detected Architecture: $ARCH ($ARCH_TYPE)"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Download and install CloudWatch agent based on OS and architecture
if [[ "$OS" == *"Amazon Linux"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"CentOS"* ]]; then
    echo "Installing on RPM-based system..."
    wget https://amazoncloudwatch-agent-ap-southeast-1.s3.ap-southeast-1.amazonaws.com/amazon_linux/${RPM_ARCH}/latest/amazon-cloudwatch-agent.rpm
    sudo rpm -U ./amazon-cloudwatch-agent.rpm
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    echo "Installing on Debian-based system..."
    wget https://amazoncloudwatch-agent-ap-southeast-1.s3.ap-southeast-1.amazonaws.com/debian/${ARCH_TYPE}/latest/amazon-cloudwatch-agent.deb
    sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
else
    echo "Unsupported OS: $OS. Exiting."
    exit 1
fi

# Clean up temporary directory
cd ~
rm -rf $TEMP_DIR

# Create CloudWatch agent configuration directory if it doesn't exist
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

# Create CloudWatch agent configuration file
echo "Creating CloudWatch agent configuration..."
cat << 'EOF' | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "InstanceType": "${aws:InstanceType}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_available",
          "mem_available_percent",
          "mem_total",
          "mem_used"
        ],
        "metrics_collection_interval": 30
      },
      "swap": {
        "measurement": [
          "swap_used_percent",
          "swap_free",
          "swap_used"
        ],
        "metrics_collection_interval": 30
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      },
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 30,
        "totalcpu": true
      },
      "processes": {
        "measurement": [
          "running",
          "sleeping",
          "dead"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "system-logs",
            "log_stream_name": "{instance_id}-messages"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "system-logs",
            "log_stream_name": "{instance_id}-secure"
          }
        ]
      }
    }
  }
}
EOF

# Start the CloudWatch agent
echo "Starting CloudWatch agent..."
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Enable CloudWatch agent to start on boot
echo "Enabling CloudWatch agent to start on boot..."
if command -v systemctl &> /dev/null; then
    sudo systemctl enable amazon-cloudwatch-agent
elif command -v chkconfig &> /dev/null; then
    sudo chkconfig amazon-cloudwatch-agent on
else
    echo "Warning: Could not enable CloudWatch agent to start on boot. Please enable it manually."
fi

# Check agent status
echo "Checking CloudWatch agent status..."
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status

# Add a simple memory monitoring script (optional)
echo "Creating memory monitoring script..."
cat << 'EOF' | sudo tee /usr/local/bin/check-memory.sh
#!/bin/bash
MEM_USED_PCT=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
echo "Memory usage: ${MEM_USED_PCT}%"
if (( $(echo "$MEM_USED_PCT > 90" | bc -l) )); then
    echo "WARNING: High memory usage detected!"
fi
EOF

sudo chmod +x /usr/local/bin/check-memory.sh

echo "=== CloudWatch Agent Installation Complete ==="
echo "You can now view metrics in the CloudWatch console under the 'CWAgent' namespace"
echo "To check memory usage quickly, run: /usr/local/bin/check-memory.sh"
