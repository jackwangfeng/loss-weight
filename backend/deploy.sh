#!/bin/bash
# Build + push + redeploy backend to openim-server EC2.
#
# Prereqs (one-time, already configured):
#   - AWS profile `recompdaily` for ECR push
#   - AWS profile `seesaw-dev` for EC2 Instance Connect SSH
#   - ~/.ssh/id_ed25519[.pub]
#   - docker buildx with linux/arm64 support
#
# Why two profiles: ECR repo lives in recompdaily account; the EC2 host
# is shared with seesaw-dev's openim-server (their VPC → their EICE).
#
# Flow:
#   1. buildx → linux/arm64 (EC2 is Graviton) → push to ECR as :v1 (overwrite)
#   2. SSH via EICE tunnel, pull, stop old, run new with secrets from SM.
#
# Usage: ./deploy.sh

set -euo pipefail

cd "$(dirname "$0")"

ECR_REPO="337909756117.dkr.ecr.ap-southeast-1.amazonaws.com/recompdaily-backend"
EC2_INSTANCE="i-0141753dd11e7d9b8"
EC2_IP="10.0.10.152"
EICE="eice-0e268a2e1f59935d3"
SSH_KEY="$HOME/.ssh/id_ed25519"

echo "=== [1/3] build + push arm64 image as :v1 ==="
AWS_PROFILE=recompdaily aws ecr get-login-password --region ap-southeast-1 \
  | docker login --username AWS --password-stdin 337909756117.dkr.ecr.ap-southeast-1.amazonaws.com >/dev/null
docker buildx build --platform linux/arm64 -f Dockerfile.prod \
  -t "$ECR_REPO:v1" --push . 2>&1 | tail -3

echo "=== [2/3] push SSH key to EC2 ==="
AWS_PROFILE=seesaw-dev aws ec2-instance-connect send-ssh-public-key \
  --region ap-southeast-1 \
  --instance-id "$EC2_INSTANCE" \
  --instance-os-user ubuntu \
  --ssh-public-key "file://${SSH_KEY}.pub" \
  --output text >/dev/null

echo "=== [3/3] pull + restart container on EC2 ==="
ssh -i "$SSH_KEY" \
  -o ProxyCommand="aws ec2-instance-connect open-tunnel --profile seesaw-dev --region ap-southeast-1 --instance-connect-endpoint-id $EICE --instance-id $EC2_INSTANCE" \
  -o StrictHostKeyChecking=no \
  ubuntu@"$EC2_IP" \
  "set -e
   export AWS_DEFAULT_REGION=ap-southeast-1
   DB_URL=\$(aws secretsmanager get-secret-value --secret-id recompdaily/prod/database-url --query SecretString --output text)
   GEMINI_KEY=\$(aws secretsmanager get-secret-value --secret-id recompdaily/prod/gemini-api-key --query SecretString --output text)
   JWT_KEY=\$(aws secretsmanager get-secret-value --secret-id recompdaily/prod/jwt-secret --query SecretString --output text)
   DG_KEY=\$(aws secretsmanager get-secret-value --secret-id recompdaily/prod/deepgram-api-key --query SecretString --output text)
   aws ecr get-login-password | sudo docker login --username AWS --password-stdin 337909756117.dkr.ecr.ap-southeast-1.amazonaws.com >/dev/null 2>&1
   sudo docker pull $ECR_REPO:v1 2>&1 | tail -1
   sudo docker rm -f recompdaily >/dev/null 2>&1 || true
   sudo docker run -d --name recompdaily --network openim-docker_openim -p 8000:8000 --restart always \\
     -e DATABASE_URL=\"\$DB_URL\" -e GEMINI_API_KEY=\"\$GEMINI_KEY\" -e SECRET_KEY=\"\$JWT_KEY\" -e DEEPGRAM_API_KEY=\"\$DG_KEY\" \\
     -e GEMINI_API_URL='https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent' \\
     -e VISION_API_URL='https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent' \\
     -e GOOGLE_CLIENT_ID='604310975641-chq87tal9oii607rigc1uq59vjsirgas.apps.googleusercontent.com' \\
     -e GOOGLE_IOS_CLIENT_ID='604310975641-kbbf1h3r3v5q81fljqdev4r9lqeoplip.apps.googleusercontent.com' \\
     -e REDIS_URL='redis://redis:6379/0' -e DEBUG=false -e GIN_MODE=release \\
     -e SKIP_SMS_VERIFY=true \\
     $ECR_REPO:v1 >/dev/null
   # ⚠️ SKIP_SMS_VERIFY=true is the friends-beta backdoor: any phone + any code
   # logs in. Enabled so the Android easter-egg (login screen → tap fitness
   # logo 7×) gives mainland-China friends a way past Google sign-in. MUST
   # turn off before App Store submission — connect Aliyun/Tencent SMS first.
   sleep 3
   curl -sS http://localhost:8000/health; echo"

echo "=== done ==="
curl -sS --max-time 5 http://13.215.200.80:8000/health; echo
