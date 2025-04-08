## RDS 实例停止助手

AWS RDS数据库实例只允许暂停7天，本项目提供了一套自动化管理脚本，用于将RDS实例保持长期停止状态，以节省成本。


### 脚本说明

1. rds_stop_script.sh - 检查并停止指定的 RDS 实例 (my-rds-instance)
2. setup_crontab.sh - 设置 crontab 任务，每7天自动运行停止脚本
3. create_rds_stop_rule.sh - 创建 CloudWatch Events 规则，每7天自动停止 RDS 实例
4. deploy_stop_lambda.sh - 部署 Lambda 函数来管理 RDS 实例


当您需要使用数据库时，可以通过 AWS 控制台手动启动


### 手动管理 RDS 实例

当您需要使用数据库时，可以通过 AWS 控制台手动启动，或使用以下命令：

```bash
aws rds start-db-instance --db-instance-identifier my-rds-instance --region us-east-1
```

 手动停止RDS实例使用 AWS CLI 命令：
```bash
aws rds stop-db-instance --db-instance-identifier my-rds-instance --region us-east-1
```

### 注意事项

- 所有脚本默认使用 `us-east-1` 区域和 `my-rds-instance` 实例
- 确保您有足够的 IAM 权限来执行这些操作
- Lambda 函数需要具有 RDS 操作权限的 IAM 角色
- 自动停止功能可以帮助节省不需要时的 RDS 实例成本
