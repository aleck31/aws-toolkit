#!/bin/bash

# 删除 S3 存储桶的脚本
# 用法: ./delete_s3_bucket.sh bucket-name [region]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}错误: 请提供存储桶名称${NC}"
    echo "用法: $0 bucket-name [region]"
    exit 1
fi

BUCKET_NAME=$1
REGION=${2:-"ap-southeast-1"} # 默认区域为 ap-southeast-1

echo -e "${BLUE}准备删除存储桶: ${YELLOW}$BUCKET_NAME${BLUE} (区域: ${YELLOW}$REGION${BLUE})${NC}"

# 检查存储桶是否存在
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
    echo -e "${RED}错误: 存储桶 '$BUCKET_NAME' 不存在或您没有访问权限${NC}"
    exit 1
fi

# 检查存储桶是否为空
OBJECTS=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --max-items 1 --region "$REGION" 2>/dev/null)
if [[ $(echo "$OBJECTS" | grep -c "Contents") -gt 0 ]]; then
    echo -e "${YELLOW}警告: 存储桶 '$BUCKET_NAME' 不为空${NC}"
    read -p "是否要删除存储桶中的所有对象? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}操作已取消${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}删除存储桶中的所有对象...${NC}"
    aws s3 rm "s3://$BUCKET_NAME" --recursive --region "$REGION"
    echo -e "${GREEN}所有对象已删除${NC}"
fi

# 检查存储桶是否启用了版本控制
VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null)
if [[ "$VERSIONING" == *"Enabled"* || "$VERSIONING" == *"Suspended"* ]]; then
    echo -e "${YELLOW}警告: 存储桶 '$BUCKET_NAME' 启用了版本控制${NC}"
    read -p "是否要删除所有版本的对象? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}操作已取消${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}删除所有版本的对象...${NC}"
    
    # 删除所有版本的对象
    VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output=json --region "$REGION")
    if [[ "$VERSIONS" != "{}" && "$VERSIONS" != *"null"* ]]; then
        echo -e "${BLUE}删除对象版本...${NC}"
        aws s3api delete-objects --bucket "$BUCKET_NAME" --delete "$VERSIONS" --region "$REGION"
    fi
    
    # 删除所有删除标记
    DELETE_MARKERS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output=json --region "$REGION")
    if [[ "$DELETE_MARKERS" != "{}" && "$DELETE_MARKERS" != *"null"* ]]; then
        echo -e "${BLUE}删除删除标记...${NC}"
        aws s3api delete-objects --bucket "$BUCKET_NAME" --delete "$DELETE_MARKERS" --region "$REGION"
    fi
    
    echo -e "${GREEN}所有版本的对象已删除${NC}"
fi

# 检查存储桶策略
POLICY=$(aws s3api get-bucket-policy --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "")
if [[ -n "$POLICY" ]]; then
    echo -e "${YELLOW}警告: 存储桶 '$BUCKET_NAME' 有策略${NC}"
    read -p "是否要删除存储桶策略? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}操作已取消${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}删除存储桶策略...${NC}"
    aws s3api delete-bucket-policy --bucket "$BUCKET_NAME" --region "$REGION"
    echo -e "${GREEN}存储桶策略已删除${NC}"
fi

# 检查存储桶是否启用了静态网站托管
WEBSITE=$(aws s3api get-bucket-website --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "")
if [[ -n "$WEBSITE" ]]; then
    echo -e "${YELLOW}警告: 存储桶 '$BUCKET_NAME' 启用了静态网站托管${NC}"
    read -p "是否要禁用静态网站托管? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}操作已取消${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}禁用静态网站托管...${NC}"
    aws s3api delete-bucket-website --bucket "$BUCKET_NAME" --region "$REGION"
    echo -e "${GREEN}静态网站托管已禁用${NC}"
fi

# 检查存储桶是否有生命周期配置
LIFECYCLE=$(aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "")
if [[ -n "$LIFECYCLE" ]]; then
    echo -e "${YELLOW}警告: 存储桶 '$BUCKET_NAME' 有生命周期配置${NC}"
    read -p "是否要删除生命周期配置? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}操作已取消${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}删除生命周期配置...${NC}"
    aws s3api delete-bucket-lifecycle --bucket "$BUCKET_NAME" --region "$REGION"
    echo -e "${GREEN}生命周期配置已删除${NC}"
fi

# 检查存储桶是否有 CORS 配置
CORS=$(aws s3api get-bucket-cors --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "")
if [[ -n "$CORS" ]]; then
    echo -e "${YELLOW}警告: 存储桶 '$BUCKET_NAME' 有 CORS 配置${NC}"
    read -p "是否要删除 CORS 配置? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}操作已取消${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}删除 CORS 配置...${NC}"
    aws s3api delete-bucket-cors --bucket "$BUCKET_NAME" --region "$REGION"
    echo -e "${GREEN}CORS 配置已删除${NC}"
fi

# 最后删除存储桶
echo -e "${BLUE}删除存储桶 '$BUCKET_NAME'...${NC}"
if aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION"; then
    echo -e "${GREEN}存储桶 '$BUCKET_NAME' 已成功删除${NC}"
else
    echo -e "${RED}删除存储桶 '$BUCKET_NAME' 失败${NC}"
    echo -e "${YELLOW}可能存在其他阻碍删除的配置，请检查 AWS 控制台${NC}"
    exit 1
fi
