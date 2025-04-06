#!/bin/bash
# EC2实例连接问题诊断工具
# 用法: ./ec2_troubleshoot.sh <实例ID> <区域> [AWS配置文件]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 将UTC时间转换为本地时间
convert_to_local_time() {
    local utc_time=$1
    # 替换T和Z，便于date命令处理
    utc_time=$(echo $utc_time | sed 's/T/ /g' | sed 's/Z//g' | sed 's/+00:00//g')
    
    # 获取系统时区（使用timedatectl，更可靠）
    local system_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null)
    
    # 如果timedatectl失败，尝试其他方法
    if [ -z "$system_timezone" ]; then
        system_timezone=$(readlink -f /etc/localtime | sed 's/.*zoneinfo\///' 2>/dev/null)
    fi
    
    # 如果仍然失败，尝试读取/etc/timezone
    if [ -z "$system_timezone" ] && [ -f "/etc/timezone" ]; then
        system_timezone=$(cat /etc/timezone 2>/dev/null)
    fi
    
    # 如果所有方法都失败，使用硬编码的Asia/Singapore
    if [ -z "$system_timezone" ]; then
        system_timezone="Asia/Singapore"
    fi
    
    # 转换为本地时间，确保使用-d参数正确处理时区转换
    # 明确指定输入是UTC时间，输出使用本地时区
    TZ=$system_timezone date -d "TZ=\"UTC\" $utc_time" "+%Y-%m-%d %H:%M:%S %Z"
}

# 检查参数
if [ $# -lt 2 ]; then
    echo -e "${RED}错误: 缺少必要参数${NC}"
    echo "用法: $0 <实例ID> <区域> [AWS配置文件]"
    echo "示例: $0 i-0a90bda0254952ef8 ap-southeast-1 myprofile"
    exit 1
fi

INSTANCE_ID=$1
REGION=$2
PROFILE=${3:-default}

# 定义时间范围变量（用于CloudWatch查询）
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -d "30 minutes ago" +"%Y-%m-%dT%H:%M:%SZ")

echo -e "${BLUE}========== EC2实例诊断工具 ==========${NC}"
echo -e "${BLUE}实例ID:${NC} $INSTANCE_ID"
echo -e "${BLUE}区域:${NC} $REGION"
echo -e "${BLUE}配置文件:${NC} $PROFILE"
echo -e "${BLUE}=====================================${NC}\n"

# 检查依赖工具
echo -e "${YELLOW}[0/7] 检查依赖工具...${NC}"
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

# 检查nc是否可用
if ! command -v nc &> /dev/null; then
    echo -e "${YELLOW}警告: nc (netcat)未安装，将跳过网络连接测试${NC}"
    echo -e "${YELLOW}请安装nc: sudo apt-get install netcat-openbsd 或 sudo yum install nc${NC}"
    SKIP_NETWORK_TEST=true
else
    echo -e "${GREEN}nc (netcat) 已安装${NC}"
    SKIP_NETWORK_TEST=false
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "${RED}缺少必要依赖，请安装后重试${NC}"
    exit 1
fi

# 检查AWS凭证
echo -e "\n${YELLOW}[1/7] 检查AWS凭证...${NC}"
if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
    echo -e "${RED}错误: AWS凭证无效或已过期${NC}"
    exit 1
else
    echo -e "${GREEN}AWS凭证有效${NC}"
    aws sts get-caller-identity --profile $PROFILE | grep Arn
fi

# 获取实例详细信息
echo -e "\n${YELLOW}[2/7] 获取实例基本信息...${NC}"
if ! INSTANCE_JSON=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --profile $PROFILE 2>/dev/null); then
    echo -e "${RED}错误: 无法获取实例信息，请检查实例ID和区域是否正确${NC}"
    exit 1
fi

# 提取关键信息
INSTANCE_STATE=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].State.Name')
INSTANCE_TYPE=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].InstanceType')
PUBLIC_IP=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
PRIVATE_IP=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
LAUNCH_TIME=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].LaunchTime')
KEY_NAME=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].KeyName')
SECURITY_GROUPS=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].SecurityGroups[].GroupId' | tr '\n' ' ')
TRANSITION_REASON=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].StateTransitionReason')
VPC_ID=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].VpcId')
SUBNET_ID=$(echo $INSTANCE_JSON | jq -r '.Reservations[0].Instances[0].SubnetId')

# 显示实例信息
echo -e "${GREEN}实例状态:${NC} $INSTANCE_STATE"
echo -e "${GREEN}实例类型:${NC} $INSTANCE_TYPE"
echo -e "${GREEN}公网IP:${NC} $PUBLIC_IP"
echo -e "${GREEN}私网IP:${NC} $PRIVATE_IP"
echo -e "${GREEN}启动时间:${NC} $LAUNCH_TIME"
echo -e "${GREEN}密钥名称:${NC} $KEY_NAME"
echo -e "${GREEN}安全组:${NC} $SECURITY_GROUPS"
echo -e "${GREEN}VPC ID:${NC} $VPC_ID"
echo -e "${GREEN}子网 ID:${NC} $SUBNET_ID"
if [ ! -z "$TRANSITION_REASON" ] && [ "$TRANSITION_REASON" != "null" ]; then
    echo -e "${GREEN}状态转换原因:${NC} $TRANSITION_REASON"
fi



# 检查VPC和子网配置
check_vpc_config() {
    echo -e "\n${BLUE}检查VPC和子网配置...${NC}"
    
    # 检查子网是否有公网IP自动分配
    SUBNET_INFO=$(aws ec2 describe-subnets --subnet-ids $SUBNET_ID --region $REGION --profile $PROFILE 2>/dev/null || echo '{"Subnets":[]}')
    MAP_PUBLIC_IP=$(echo $SUBNET_INFO | jq -r '.Subnets[0].MapPublicIpOnLaunch')
    
    if [ "$MAP_PUBLIC_IP" == "true" ]; then
        echo -e "${GREEN}子网配置: 自动分配公网IP${NC}"
    else
        echo -e "${YELLOW}子网配置: 不自动分配公网IP${NC}"
        if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "null" ]; then
            echo -e "${RED}警告: 实例没有公网IP，且子网不自动分配公网IP${NC}"
        fi
    fi
    
    # 检查是否有互联网网关
    VPC_INFO=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION --profile $PROFILE 2>/dev/null || echo '{"Vpcs":[]}')
    IGW_INFO=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region $REGION --profile $PROFILE 2>/dev/null || echo '{"InternetGateways":[]}')
    IGW_COUNT=$(echo $IGW_INFO | jq -r '.InternetGateways | length')
    
    if [ "$IGW_COUNT" -gt 0 ]; then
        IGW_ID=$(echo $IGW_INFO | jq -r '.InternetGateways[0].InternetGatewayId')
        echo -e "${GREEN}VPC已连接互联网网关: $IGW_ID${NC}"
    else
        echo -e "${RED}警告: VPC没有连接互联网网关，实例可能无法访问互联网${NC}"
    fi
    
    # 检查路由表
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.subnet-id,Values=$SUBNET_ID" --region $REGION --profile $PROFILE 2>/dev/null || echo '{"RouteTables":[]}')
    ROUTE_COUNT=$(echo $ROUTE_TABLES | jq -r '.RouteTables | length')
    
    if [ "$ROUTE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}子网关联的路由表:${NC}"
        INTERNET_ROUTE=$(echo $ROUTE_TABLES | jq -r '.RouteTables[0].Routes[] | select(.DestinationCidrBlock=="0.0.0.0/0")')
        if [ ! -z "$INTERNET_ROUTE" ]; then
            IGW_ROUTE=$(echo $INTERNET_ROUTE | grep "igw-")
            if [ ! -z "$IGW_ROUTE" ]; then
                echo -e "${GREEN}存在通往互联网的路由${NC}"
            else
                echo -e "${RED}警告: 没有通往互联网网关的路由${NC}"
            fi
        else
            echo -e "${RED}警告: 没有默认路由 (0.0.0.0/0)${NC}"
        fi
    else
        echo -e "${YELLOW}未找到与子网关联的路由表${NC}"
    fi
}

# 检查实例运行状态
echo -e "\n${YELLOW}[3/7] 检查实例运行状态...${NC}"
if [ "$INSTANCE_STATE" != "running" ]; then
    echo -e "${RED}警告: 实例不在运行状态，当前状态为: $INSTANCE_STATE${NC}"
    if [ "$INSTANCE_STATE" == "stopping" ]; then
        echo -e "${YELLOW}实例卡在stopping状态，可能是底层硬件故障${NC}"
        echo -e "${YELLOW}建议联系AWS支持或尝试强制停止:${NC}"
        echo -e "aws ec2 stop-instances --instance-ids $INSTANCE_ID --force --region $REGION --profile $PROFILE"
    fi
else
    echo -e "${GREEN}实例运行正常 (running)${NC}"
    # 检查VPC配置（如果实例状态为running）
    check_vpc_config
fi


# 检查健康检查状态
echo -e "\n${YELLOW}[4/7] 检查实例健康检查状态...${NC}"
STATUS_DATA=$(aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name StatusCheckFailed \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID --start-time $START_TIME --end-time $END_TIME \
    --period 300 --statistics Maximum --region $REGION --profile $PROFILE 2>/dev/null || echo '{"Datapoints":[]}')

STATUS_POINTS=$(echo $STATUS_DATA | jq -r '.Datapoints | length')

if [ "$STATUS_POINTS" -gt 0 ]; then
    FAILED_CHECKS=$(echo $STATUS_DATA | jq -r '.Datapoints[] | select(.Maximum > 0) | .Timestamp')
    if [ ! -z "$FAILED_CHECKS" ]; then
        echo -e "${RED}警告: 检测到健康检查失败:${NC}"
        for timestamp in $FAILED_CHECKS; do
            local_time=$(convert_to_local_time "$timestamp")
            echo "$local_time"
        done
    else
        echo -e "${GREEN}所有健康检查均通过${NC}"
    fi
else
    echo -e "${YELLOW}无可用的健康检查数据${NC}"
fi


# 检查安全组配置
echo -e "\n${YELLOW}[5/7] 检查安全组配置...${NC}"
for SG_ID in $SECURITY_GROUPS; do
    echo -e "${BLUE}安全组 $SG_ID 的入站规则:${NC}"
    aws ec2 describe-security-groups --group-ids $SG_ID --region $REGION --profile $PROFILE --query 'SecurityGroups[0].IpPermissions' --output table
    
    # 检查SSH端口
    if aws ec2 describe-security-groups --group-ids $SG_ID --region $REGION --profile $PROFILE --query 'SecurityGroups[0].IpPermissions[?ToPort==`22`]' --output text | grep -q "22"; then
        echo -e "${GREEN}安全组 $SG_ID 允许SSH连接 (端口22)${NC}"
        SSH_ALLOWED=true
    fi
done

if [ -z "$SSH_ALLOWED" ]; then
    echo -e "${RED}警告: 没有安全组允许SSH连接 (端口22)${NC}"
fi


# 测试网络连接
echo -e "\n${YELLOW}[6/7] 测试网络连接...${NC}"
if [ "$SKIP_NETWORK_TEST" = true ]; then
    echo -e "${YELLOW}跳过网络测试，因为缺少必要工具${NC}"
elif [ ! -z "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "null" ]; then
    echo -e "${BLUE}测试ICMP连通性 (ping)...${NC}"
    if ping -c 1 -W 2 $PUBLIC_IP &> /dev/null; then
        echo -e "${GREEN}ICMP连通性正常${NC}"
    else
        echo -e "${RED}ICMP连通性失败${NC}"
    fi
    
    echo -e "${BLUE}测试SSH端口 (22)...${NC}"
    if nc -z -w 5 $PUBLIC_IP 22 &> /dev/null; then
        echo -e "${GREEN}SSH端口 (22) 开放${NC}"
    else
        echo -e "${RED}SSH端口 (22) 关闭或被阻止${NC}"
    fi
else
    echo -e "${RED}实例没有公网IP，无法进行网络测试${NC}"
fi


# 检查CPU利用率
echo -e "\n${YELLOW}[7/7] 检查CPU利用率 (过去30分钟)...${NC}"

CPU_DATA=$(aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID --start-time $START_TIME --end-time $END_TIME \
    --period 300 --statistics Average --region $REGION --profile $PROFILE 2>/dev/null || echo '{"Datapoints":[]}')

CPU_POINTS=$(echo $CPU_DATA | jq -r '.Datapoints | length')

if [ "$CPU_POINTS" -gt 0 ]; then
    echo -e "${GREEN}CPU利用率数据:${NC}"
    # 使用jq提取时间戳和CPU值，然后转换时间
    echo $CPU_DATA | jq -r '.Datapoints[] | [.Timestamp, .Average] | @tsv' | while read timestamp cpu; do
        local_time=$(convert_to_local_time "$timestamp")
        echo "时间: $local_time - CPU: $cpu%"
    done | sort
    
    # 检查高CPU使用率
    HIGH_CPU=$(echo $CPU_DATA | jq -r '.Datapoints[].Average' | awk '$1 > 90 {print}')
    if [ ! -z "$HIGH_CPU" ]; then
        echo -e "${RED}警告: 检测到高CPU使用率 (>90%)，可能导致SSH连接问题${NC}"
    fi
else
    echo -e "${YELLOW}无可用的CPU利用率数据${NC}"
fi


# 总结和建议
echo -e "\n${BLUE}========== 诊断总结 ==========${NC}"

if [ "$INSTANCE_STATE" != "running" ]; then
    echo -e "${RED}[问题] 实例不在运行状态${NC}"
    echo -e "${YELLOW}建议: 等待实例状态变为running，或尝试启动实例${NC}"
elif [ -z "$SSH_ALLOWED" ]; then
    echo -e "${RED}[问题] 安全组不允许SSH连接${NC}"
    echo -e "${YELLOW}建议: 修改安全组规则，允许端口22的入站流量${NC}"
elif [ ! -z "$FAILED_CHECKS" ]; then
    echo -e "${RED}[问题] 实例状态检查失败${NC}"
    echo -e "${YELLOW}建议: 检查系统日志或重启实例${NC}"
elif [ ! -z "$HIGH_CPU" ]; then
    echo -e "${RED}[问题] 检测到高CPU使用率${NC}"
    echo -e "${YELLOW}建议: 重启实例或检查实例上运行的进程${NC}"
elif [ "$INSTANCE_STATE" == "running" ] && [ ! -z "$PUBLIC_IP" ] && nc -z -w 5 $PUBLIC_IP 22 &> /dev/null; then
    echo -e "${GREEN}实例状态和网络连接正常，如仍无法SSH连接${NC}"
    echo -e "${YELLOW}建议检查:${NC}"
    echo -e "1. SSH密钥是否正确 ($KEY_NAME)"
    echo -e "2. 使用正确的用户名 (通常为ubuntu, ec2-user, admin等，取决于AMI)"
    echo -e "3. 实例内部的SSH配置或防火墙规则"
    echo -e "4. 尝试使用EC2 Instance Connect或Session Manager连接"
else
    echo -e "${RED}可能存在多个问题，请检查上述详细信息${NC}"
fi

echo -e "\n${BLUE}=====================================${NC}"
echo -e "${YELLOW}如果问题持续存在，可以尝试:${NC}"
echo -e "1. 重启实例: aws ec2 reboot-instances --instance-ids $INSTANCE_ID --region $REGION --profile $PROFILE"
echo -e "2. 停止并启动实例: aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION --profile $PROFILE"
echo -e "   等待实例停止后: aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION --profile $PROFILE"
echo -e "3. 如果实例卡在stopping状态，尝试强制停止: aws ec2 stop-instances --instance-ids $INSTANCE_ID --force --region $REGION --profile $PROFILE"
echo -e "4. 获取系统日志: aws ec2 get-console-output --instance-id $INSTANCE_ID --region $REGION --profile $PROFILE"
echo -e "5. 联系AWS支持"
