# AWS Toolkit

AWS Toolkit is a collection of utilities designed to simplify the management, monitoring, and troubleshooting of AWS cloud services. This repository contains a series of scripts and tools that help AWS users manage cloud resources more efficiently.

## Tool List

- **EC2 Connection Troubleshooter** (`ec2_conn_troubleshoot`)
  A diagnostic tool that helps identify and resolve EC2 instance connection issues by checking instance status, security group settings, CPU load, and other potential failure points.

- **RDS Status Check** (`rds_status_check`)
  A monitoring tool that automatically checks the status of RDS/Aurora database instances during creation or modification processes. It provides real-time updates and connection details once the database is available.

- **CloudWatch Agent Installer** (`ec2_install_cwagent`)
  A script that automates the installation and configuration of the CloudWatch agent on EC2 instances. It supports multiple architectures (x86_64 and ARM64) and operating systems (Amazon Linux, RHEL, Ubuntu, and Debian).

- **RDS Instance Stop Assistant** (`rds_instance_stop`)
  A set of automation scripts to keep RDS instances in a stopped state beyond the 7-day limit, helping to save costs. Includes options for cron jobs and CloudWatch Events rules.

- **S3 Bucket Killer** (`s3-bucket-killer`)
  A command-line tool for safely deleting AWS S3 buckets, handling various obstacles such as non-empty buckets, versioning, bucket policies, and other configurations that might prevent deletion.

- **AWS Resource Tracker** [https://github.com/aleck31/aws-resource-tracker]
  A solution for monitoring and tracking AWS resource creation and deletion operations, including a web interface for viewing historical records.

## Todo List

- CloudWatch Alarm Management Tool
- ECS Service Deployment Assistant

## Usage

Each tool includes its own README file with detailed usage instructions. Generally, the tools follow this pattern:

```bash
# Make the script executable
chmod +x script_name.sh

# Run the script with required parameters
./script_name.sh <required_param> [optional_param]
```

## Requirements

- AWS CLI installed and configured
- Appropriate IAM permissions for the operations performed by each tool
- Additional dependencies as specified in individual tool documentation

## License

[MIT License](LICENSE)
