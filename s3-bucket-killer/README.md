## S3 存储桶快捷删除

这是一个用于安全删除 AWS S3 存储桶的命令行工具。它能够处理各种阻碍删除的情况，如非空存储桶、启用版本控制的存储桶等，并在每个关键步骤提供用户确认选项。

### 功能特点

- 自动检测并处理非空存储桶
- 处理启用了版本控制的存储桶（删除所有版本和删除标记）
- 删除存储桶策略
- 禁用静态网站托管
- 删除生命周期配置
- 删除 CORS 配置
- 友好的提示输出和交互式确认

### 方法

1. 确保脚本具有执行权限：

```bash
chmod +x delete_s3_bucket.sh
```

2. 运行脚本，指定要删除的存储桶名称：

```bash
./delete_s3_bucket.sh bucket-name
```

3. 如果存储桶不在默认区域 (ap-southeast-1)，可以指定区域：

```bash
./delete_s3_bucket.sh bucket-name us-east-1
```

## 示例

```bash
# 删除位于 ap-southeast-1 区域的存储桶
./delete_s3_bucket.sh my-test-bucket

# 删除位于 us-west-2 区域的存储桶
./delete_s3_bucket.sh my-other-bucket us-west-2
```

#### 依赖项

- AWS CLI
- 具有删除 S3 存储桶的 IAM 权限


### 安全提示

- 在生产环境中使用前，请先在测试环境中验证脚本
- 确保您有权限删除指定的存储桶
- 删除前请确认存储桶中没有重要数据
- 删除操作是不可逆的，请谨慎使用
- 某些特殊配置（如复制规则、对象锁定等）可能需要额外处理
