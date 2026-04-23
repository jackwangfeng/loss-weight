#!/bin/bash
# 从本地通过 EC2 Instance Connect 隧道连接 Dev RDS
#
# 使用方式:
#   ./connect-dev-rds.sh          # 打开 psql 交互终端
#   ./connect-dev-rds.sh -c "SQL" # 执行单条 SQL
#
# 依赖:
#   - aws cli (已配置 seesaw-dev profile)
#   - ssh + ~/.ssh/id_ed25519 密钥对
#   - psql 客户端

set -e

# ============ 配置 ============
AWS_PROFILE="seesaw-dev"
AWS_REGION="ap-southeast-1"
EC2_INSTANCE_ID="i-0141753dd11e7d9b8"
EC2_USER="ubuntu"
EC2_IP="10.0.10.152"
EICE_ID="eice-0e268a2e1f59935d3"
SSH_KEY="$HOME/.ssh/id_ed25519"

RDS_HOST="seesaw-dev.c1wwy4w8ee4t.ap-southeast-1.rds.amazonaws.com"
RDS_PORT=5432
LOCAL_PORT=15432
DB_NAME="postgres"
DB_USER="postgres"

# 从 AWS Secrets Manager 获取密码
SECRET_ID="seesaw/dev/db-password"

# ============ 函数 ============
cleanup() {
    if [ -n "$SSH_PID" ] && kill -0 "$SSH_PID" 2>/dev/null; then
        kill "$SSH_PID" 2>/dev/null
        echo "✅ SSH 隧道已关闭"
    fi
}
trap cleanup EXIT

check_port() {
    lsof -i :$LOCAL_PORT >/dev/null 2>&1
}

# ============ 主流程 ============
echo "🔐 获取数据库密码..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --secret-id "$SECRET_ID" \
    --query "SecretString" \
    --output text 2>/dev/null)

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ 获取密码失败，请确认 AWS 凭证和权限"
    exit 1
fi

# 检查端口是否已被占用（可能已有隧道）
if check_port; then
    echo "⚡ 端口 $LOCAL_PORT 已在使用，尝试直接连接..."
else
    echo "🔑 推送临时 SSH 公钥（60秒有效）..."
    aws ec2-instance-connect send-ssh-public-key \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --instance-id "$EC2_INSTANCE_ID" \
        --instance-os-user "$EC2_USER" \
        --ssh-public-key "file://${SSH_KEY}.pub" \
        --output text >/dev/null

    echo "🚇 建立 SSH 隧道 (localhost:$LOCAL_PORT -> RDS:$RDS_PORT)..."
    ssh -i "$SSH_KEY" -N \
        -L ${LOCAL_PORT}:${RDS_HOST}:${RDS_PORT} \
        -o ProxyCommand="aws ec2-instance-connect open-tunnel --profile $AWS_PROFILE --region $AWS_REGION --instance-connect-endpoint-id $EICE_ID --instance-id $EC2_INSTANCE_ID" \
        -o StrictHostKeyChecking=no \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        ${EC2_USER}@${EC2_IP} &
    SSH_PID=$!

    # 等待隧道就绪
    echo -n "⏳ 等待隧道就绪"
    for i in $(seq 1 15); do
        if check_port; then
            echo " ✅"
            break
        fi
        echo -n "."
        sleep 1
    done

    if ! check_port; then
        echo " ❌ 隧道建立超时"
        exit 1
    fi
fi

echo "🎯 连接 Dev RDS ($RDS_HOST)"
echo "---"

# 连接数据库
PGPASSWORD="$DB_PASSWORD" psql \
    "host=127.0.0.1 port=$LOCAL_PORT dbname=$DB_NAME user=$DB_USER sslmode=require" \
    "$@"
