# deploy.ps1 – Despliegue completo del Bill Checker en AWS Lambda
# Uso: .\deploy.ps1
# Prerequisitos: AWS CLI, Docker Desktop corriendo, SAM CLI

$ErrorActionPreference = "Stop"

$REGION       = "us-east-1"
$STACK_NAME   = "money-api-stack"
$ECR_REPO     = "money-api"
$IMAGE_TAG    = "latest"

Write-Host "`n========== PASO 1: Verificando herramientas ==========" -ForegroundColor Cyan
try { aws --version | Out-Null } catch { Write-Host "ERROR: AWS CLI no esta instalado" -ForegroundColor Red; exit 1 }
try { docker --version | Out-Null } catch { Write-Host "ERROR: Docker no esta instalado o no esta corriendo" -ForegroundColor Red; exit 1 }
try { sam --version | Out-Null } catch { Write-Host "ERROR: SAM CLI no esta instalado. Ejecuta: pip install aws-sam-cli" -ForegroundColor Red; exit 1 }
Write-Host "OK - Todas las herramientas instaladas" -ForegroundColor Green

Write-Host "`n========== PASO 2: Obteniendo Account ID ==========" -ForegroundColor Cyan
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$ECR_URI    = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"
$FULL_IMAGE = "${ECR_URI}:${IMAGE_TAG}"
Write-Host "Account: $ACCOUNT_ID"
Write-Host "Image:   $FULL_IMAGE"

Write-Host "`n========== PASO 3: Creando repositorio ECR ==========" -ForegroundColor Cyan
$repoExists = aws ecr describe-repositories --repository-names $ECR_REPO --region $REGION 2>$null
if (-not $repoExists) {
    aws ecr create-repository --repository-name $ECR_REPO --region $REGION --image-scanning-configuration scanOnPush=true | Out-Null
    Write-Host "Repositorio creado" -ForegroundColor Green
} else {
    Write-Host "Repositorio ya existe" -ForegroundColor Yellow
}

Write-Host "`n========== PASO 4: Login en ECR ==========" -ForegroundColor Cyan
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

Write-Host "`n========== PASO 5: Construyendo imagen Docker ==========" -ForegroundColor Cyan
Write-Host "Esto puede tardar 5-15 minutos la primera vez..." -ForegroundColor Yellow
docker build -t "${ECR_REPO}:${IMAGE_TAG}" .
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Fallo al construir la imagen" -ForegroundColor Red; exit 1 }
Write-Host "Imagen construida exitosamente" -ForegroundColor Green

Write-Host "`n========== PASO 6: Subiendo imagen a ECR ==========" -ForegroundColor Cyan
docker tag "${ECR_REPO}:${IMAGE_TAG}" $FULL_IMAGE
docker push $FULL_IMAGE
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Fallo al subir la imagen" -ForegroundColor Red; exit 1 }
Write-Host "Imagen subida exitosamente" -ForegroundColor Green

Write-Host "`n========== PASO 7: Desplegando con SAM ==========" -ForegroundColor Cyan
sam deploy `
    --template-file template.yaml `
    --stack-name $STACK_NAME `
    --region $REGION `
    --parameter-overrides "ImageUri=$FULL_IMAGE" `
    --capabilities CAPABILITY_IAM `
    --no-confirm-changeset `
    --no-fail-on-empty-changeset

Write-Host "`n========== PASO 8: Obteniendo URL del API ==========" -ForegroundColor Cyan
$API_URL = (aws cloudformation describe-stacks `
    --stack-name $STACK_NAME `
    --region $REGION `
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' `
    --output text)

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  DESPLIEGUE COMPLETO!" -ForegroundColor Green
Write-Host "  URL del API: $API_URL" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "`nPrueba con:"
Write-Host "  curl $API_URL/health"
Write-Host "  curl -X POST $API_URL/analyze -F 'image=@billete.jpg'"
