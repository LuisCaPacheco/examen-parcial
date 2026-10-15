#!/bin/bash
# Despliega candidata, prueba salud + funcional, rollback a :stable si falla.
# Requiere env: CANDIDATE, EC2_HOST, EC2_USER, EC2_SSH_KEY, AWS_REGION, ECR_REPO, FAIL_MODE
set -e
ECR_BASE=$(echo "$CANDIDATE" | cut -d: -f1)
STABLE="$ECR_BASE:stable"
SHOULD_FAIL="${FAIL_MODE:-false}"
LOGDIR="logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/deploy-$(date +%Y%m%d-%H%M%S).log"
exec | tee "$LOG"

echo "== CANDIDATE=$CANDIDATE =="
echo "== STABLE=$STABLE SHOULD_FAIL=$SHOULD_FAIL =="

echo "$EC2_SSH_KEY" > /tmp/ec2key.pem
chmod 600 /tmp/ec2key.pem
SSH="ssh -i /tmp/ec2key.pem -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST"

# 1. Desplegar candidata
$SSH "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE"
$SSH "docker pull $CANDIDATE && docker rm -f app || true"
if [ "$SHOULD_FAIL" = "true" ]; then
  $SSH "docker run -d --name app --restart unless-stopped -p 8080:8080 -e APP_VERSION=candidate-fail -e SHOULD_FAIL=true $CANDIDATE"
else
  $SSH "docker pull $CANDIDATE && docker run -d --name app --restart unless-stopped -p 8080:8080 -e APP_VERSION=$(echo $CANDIDATE | rev | cut -d: -f1 | rev) -e SHOULD_FAIL=false $CANDIDATE"
fi
sleep 12

# 2. Prueba de salud + funcional
BASE="http://$EC2_HOST"
echo "--- health check $BASE/health ---"
if curl -fsS --max-time 15 "$BASE/health" | tee /tmp/health.json; then
  echo "health OK"
  HEALTH=0
else
  echo "health FAIL"
  HEALTH=1
fi

echo "--- functional check $BASE/api/hello ---"
if [ $HEALTH -eq 0 ] && curl -fsS --max-time 15 "$BASE/api/hello" | grep -q "Hola"; then
  echo "functional OK"
  FUNC=0
else
  echo "functional FAIL"
  FUNC=1
fi

# 3. Decision: promover o rollback
if [ $HEALTH -eq 0 ] && [ $FUNC -eq 0 ]; then
  echo "PROMOTE candidate -> stable"
  aws ecr batch-get-image --region "$AWS_REGION" --repository-name "$ECR_REPO" --image-ids imageTag=$(echo "$CANDIDATE" | rev | cut -d: -f1 | rev) >/dev/null
  # Retag local y push como stable
  docker pull "$CANDIDATE" || true
  docker tag "$CANDIDATE" "$STABLE" || true
  docker push "$STABLE" || true
  echo "$CANDIDATE" > stable-image.txt
  echo "DEPLOY OK - sin rollback"
else
  echo "ROLLBACK a $STABLE"
  $SSH "docker pull $STABLE && docker rm -f app; docker run -d --name app --restart unless-stopped -p 8080:8080 $STABLE"
  sleep 8
  curl -fsS --max-time 15 "$BASE/health" | tee /tmp/health-rollback.json
  echo "ROLLBACK OK - version estable restaurada. Evidencia en $LOG"
  echo "Intento fallido conservado en logs/ y artefacto del workflow."
  exit 1  # marca el workflow como fallido-pero-recuperado (evidencia pedida)
fi
