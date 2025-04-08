#!/bin/bash
# 脚本用于检查 RDS/Aurora 数据库实例状态

set -e

# 默认配置参数
CHECK_INTERVAL=60  # 检查间隔，单位为秒

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示使用方法
function show_usage {
    echo -e "${RED}错误: 缺少必要参数${NC}"
    echo "用法: $0 <Instance ID> <Region> [Profile Name]"
    echo "示例: $0 my-aurora-instance us-west-2"
    echo "示例: $0 my-aurora-instance us-east-1 my-profile"
    exit 1
}

# 检查参数
if [ $# -lt 2 ]; then
    show_usage
fi

# 设置参数
DB_INSTANCE_ID=$1
REGION=$2
PROFILE=${3:-default}  # 如果未提供第三个参数，则使用default

echo -e "${BLUE}========== RDS/Aurora 数据库状态监控 ==========${NC}"
echo -e "${BLUE}数据库实例ID:${NC} $DB_INSTANCE_ID"
echo -e "${BLUE}区域:${NC} $REGION"
echo -e "${BLUE}配置文件:${NC} $PROFILE"
echo -e "${BLUE}检查间隔:${NC} ${CHECK_INTERVAL}秒"
echo -e "${BLUE}=====================================${NC}\n"

# 检查依赖工具
echo -e "${YELLOW}[1/3] 检查依赖工具...${NC}"
MISSING_DEPS=0

# 检查AWS CLI是否可用
if ! command -v aws &> /dev/null; then
    echo -e "${RED}错误: AWS CLI未安装${NC}"
    MISSING_DEPS=1
else
    echo -e "${GREEN}AWS CLI 已安装${NC}"
fi

# 检查jq是否可用
if ! command -v jq &> /dev/null; then
    echo -e "${RED}错误: jq未安装，无法解析JSON响应${NC}"
    echo -e "${YELLOW}请安装jq: sudo apt-get install jq 或 sudo yum install jq${NC}"
    MISSING_DEPS=1
else
    echo -e "${GREEN}jq 已安装${NC}"
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "${RED}缺少必要依赖，请安装后重试${NC}"
    exit 1
fi

# 检查AWS凭证
echo -e "\n${YELLOW}[2/3] 检查AWS凭证...${NC}"
if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
    echo -e "${RED}错误: AWS凭证无效或已过期${NC}"
    exit 1
else
    echo -e "${GREEN}AWS凭证有效${NC}"
    aws sts get-caller-identity --profile $PROFILE | grep Arn
fi

# 首先检查数据库实例是否存在
echo -e "\n${YELLOW}[3/3] 验证数据库实例...${NC}"
if ! aws rds describe-db-instances \
    --db-instance-identifier ${DB_INSTANCE_ID} \
    --region ${REGION} \
    --profile ${PROFILE} \
    --query 'DBInstances[0].DBInstanceIdentifier' \
    --output text &> /dev/null; then
    echo -e "${RED}错误: 无法找到数据库实例 ${DB_INSTANCE_ID}，请检查实例ID和区域是否正确${NC}"
    exit 1
else
    echo -e "${GREEN}数据库实例存在，开始监控状态...${NC}"
fi

echo -e "\n${BLUE}开始监控数据库状态，按 Ctrl+C 停止监控${NC}"
echo -e "${BLUE}=====================================${NC}\n"

start_time=$(date +%s)

while true; do
    # 获取数据库实例状态
    status=$(aws rds describe-db-instances \
        --db-instance-identifier ${DB_INSTANCE_ID} \
        --region ${REGION} \
        --profile ${PROFILE} \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null)
    
    # 检查命令是否成功执行
    if [ $? -ne 0 ]; then
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] 错误: 无法获取数据库状态，请检查凭证和网络连接${NC}"
        sleep ${CHECK_INTERVAL}
        continue
    fi
    
    # 计算已经等待的时间
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    hours=$((elapsed / 3600))
    minutes=$(( (elapsed % 3600) / 60 ))
    seconds=$((elapsed % 60))
    
    # 显示状态和等待时间
    if [ "$status" == "available" ]; then
        echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] 数据库实例已就绪! 状态: ${status}${NC}"
        echo -e "${GREEN}总等待时间: ${hours}小时 ${minutes}分钟 ${seconds}秒${NC}"
        
        # 获取数据库连接信息
        endpoint=$(aws rds describe-db-instances \
            --db-instance-identifier ${DB_INSTANCE_ID} \
            --region ${REGION} \
            --profile ${PROFILE} \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
        
        port=$(aws rds describe-db-instances \
            --db-instance-identifier ${DB_INSTANCE_ID} \
            --region ${REGION} \
            --profile ${PROFILE} \
            --query 'DBInstances[0].Endpoint.Port' \
            --output text)
        
        engine=$(aws rds describe-db-instances \
            --db-instance-identifier ${DB_INSTANCE_ID} \
            --region ${REGION} \
            --profile ${PROFILE} \
            --query 'DBInstances[0].Engine' \
            --output text)
        
        echo -e "${GREEN}连接信息:${NC}"
        echo -e "${GREEN}Endpoint: ${endpoint}${NC}"
        echo -e "${GREEN}Port: ${port}${NC}"
        echo -e "${GREEN}Engine: ${engine}${NC}"
        
        # 可选：发送通知
        # 取消下面的注释并替换为您的通知命令
        # notify-send "Aurora 数据库就绪" "数据库实例 ${DB_INSTANCE_ID} 现在可用"
        
        break
    elif [ "$status" == "creating" ]; then
        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] 数据库实例仍在创建中... 已等待: ${hours}小时 ${minutes}分钟 ${seconds}秒${NC}"
    else
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] 数据库状态: ${status} 已等待: ${hours}小时 ${minutes}分钟 ${seconds}秒${NC}"
    fi
    
    sleep ${CHECK_INTERVAL}
done

echo -e "\n${BLUE}========== 监控结束 ==========${NC}"
echo -e "${GREEN}数据库实例 ${DB_INSTANCE_ID} 已准备就绪${NC}"
echo -e "${BLUE}=====================================${NC}"
