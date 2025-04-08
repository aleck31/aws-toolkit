## EC2 实例连接问题诊断工具

这个脚本帮助诊断 EC2 实例的连接问题，通过检查实例运行状态，安全组设置，CPU负载 等方面来确定可能的故障点。

#### 用法

```bash
./ec2_conn_troubleshoot.sh <Instance ID> <Region> [Profile Name]
```

示例：
```bash
./ec2_conn_troubleshoot.sh i-0a90bda0254952ef8 us-east-1 myprofile
```

参数说明：
- `<Instance ID>`: 要诊断的 EC2 实例 ID（必需）
- `<Region>`: 实例所在的 AWS 区域（必需）
- `[Profile Name]`: AWS CLI 配置文件名称（可选，默认为 "default"）

#### 依赖项

- AWS CLI
- jq (用于解析 JSON)
- nc (netcat，用于网络测试)
- ping (用于 ICMP 测试)
