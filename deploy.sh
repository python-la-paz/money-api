#!/usr/bin/env bash
# deploy.sh – Build, push, and deploy the Bill Checker Lambda
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh                              # uses defaults
#   ./deploy.sh my-region my-stack my-repo   # override values
#
# Prerequisites:
#   - AWS CLI v2 configured (aws configure)
#   - Docker running
#   - AWS SAM CLI installed  (pip install aws-sam-cli)

set -euo pipefail

# ── Configurable variables ─────────────────────────────────────────────
AWS_REGION="${1:-us-east-1}"
STACK_NAME="${2:-bill-checker-stack}"
ECR_REPO_NAME="${3:-bill-checker}"
IMAGE_TAG="latest"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
FULL_IMAGE="${ECR_URI}:${IMAGE_TAG}"

echo "==> Account:  ${ACCOUNT_ID}"
echo "==> Region:   ${AWS_REGION}"
echo "==> ECR repo: ${ECR_REPO_NAME}"
echo "==> Image:    ${FULL_IMAGE}"
echo ""

# ── 1. Create ECR repository (idempotent) ──────────────────────────────
echo "==> Creating ECR repository (if not exists)..."
aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" \
    --region "${AWS_REGION}" > /dev/null 2>&1 \
  || aws ecr create-repository --repository-name "${ECR_REPO_NAME}" \
       --region "${AWS_REGION}" --image-scanning-configuration scanOnPush=true

# ── 2. Docker login to ECR ─────────────────────────────────────────────
echo "==> Logging into ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# ── 3. Build Docker image ──────────────────────────────────────────────
echo "==> Building Docker image..."
docker build -t "${ECR_REPO_NAME}:${IMAGE_TAG}" .

# ── 4. Tag & push to ECR ───────────────────────────────────────────────
echo "==> Pushing image to ECR..."
docker tag "${ECR_REPO_NAME}:${IMAGE_TAG}" "${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

# ── 5. Deploy with SAM ──────────────────────────────────────────────────
echo "==> Deploying SAM stack..."
sam deploy \
  --template-file template.yaml \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --parameter-overrides "ImageUri=${FULL_IMAGE}" \
  --capabilities CAPABILITY_IAM \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

# ── 6. Print endpoint ──────────────────────────────────────────────────
API_URL=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)

echo ""
echo "============================================"
echo "  Deployment complete!"
echo "  API endpoint: ${API_URL}"
echo "============================================"
echo ""
echo "Test with:"
echo "  curl ${API_URL}/health"
echo "  curl -X POST ${API_URL}/analyze -F 'image=@bill.jpg'"
