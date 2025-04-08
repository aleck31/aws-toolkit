## RDS 数据库状态监控工具

RDS/Aurora 数据库实例创建过程比较耗时，本脚本可以帮您自动监控数据库实例的部署进度，并在数据库实例准备就绪时提供相关的连接详情。

### 功能特点

- 默认每 60 秒检查一次 RDS/Aurora 实例状态
- 显示数据库创建过程中的等待时间
- 当数据库可用时，自动显示连接信息（端点、端口等）

### 使用方法

1. 确保脚本具有执行权限：

```bash
chmod +x rds_status_check.sh
```

2. 运行脚本，指定数据库实例 ID 和区域：

```bash
./rds_status_check.sh <Instance ID> <Region> [Profile Name]
```

### 示例

```bash
# 监控 us-west-2 区域中的 Aurora 实例
./rds_status_check.sh my-aurora-instance us-west-2

# 使用自定义配置文件监控 us-east-1 区域中的 Aurora 实例
./rds_status_check.sh my-aurora-instance us-east-1 my-profile
```

### 依赖项

- AWS CLI
- 具有查询 RDS 实例的 IAM 权限

### 提示

- 脚本默认每 60 秒检查一次数据库状态
- 按 Ctrl+C 可随时停止监控
- 当数据库状态变为 "available" 时，脚本将自动退出并显示连接信息
