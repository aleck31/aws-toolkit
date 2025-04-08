## CloudWatch 代理安装工具

这是一个用于在 EC2 实例上自动安装和配置 CloudWatch 代理的命令行工具。它能够自动检测操作系统和架构，安装适当的代理软件包，并配置全面的指标和日志收集设置。

### 功能特点

- 自动检测操作系统类型（Amazon Linux、RHEL、CentOS、Ubuntu、Debian）
- 支持多种架构（x86_64/amd64 和 ARM64/aarch64）
- 全面的Cloudwatch指标收集配置
- 系统日志收集配置
- 自动启动配置
- 添加简易内存监控脚本

#### 依赖项

- EC2 Instance Profile 权限(附加: AmazonSSMManagedInstanceCore, CloudWatchAgentServerPolicy)
- wget（用于下载代理软件包）
- bc（用于内存监控脚本）

### 使用方法

1. 确保脚本具有执行权限：

```bash
chmod +x install-cloudwatch-agent.sh
```

2. 在 EC2 实例上运行脚本：

```bash
sudo ./install-cloudwatch-agent.sh
```

### 收集的指标

该脚本配置 CloudWatch 代理收集以下指标：

- **内存**：使用百分比、可用内存、总内存
- **交换分区**：使用百分比、可用交换空间、已用交换空间
- **磁盘**：使用百分比、可用 inodes
- **CPU**：空闲使用率、IO 等待、用户使用率、系统使用率
- **进程**：运行中、休眠、终止

### 收集的日志

该脚本配置 CloudWatch 代理收集以下日志：

- `/var/log/messages`（系统消息）
- `/var/log/secure`（安全和认证消息）

### 安全提示

- 在生产环境中部署前，请检查配置文件
- 根据您的监控需求，考虑自定义指标收集间隔
- 对于生产用途，您可能需要自定义日志收集设置
