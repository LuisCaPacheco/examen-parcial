#!/bin/bash
# Taller 5 en Azure: despliega candidata con Terraform, prueba salud + funcional,
# y hace rollback a :stable (tambien con Terraform) si alguna prueba falla.
# Todo cambio pasa por Terraform: no hay drift, la version estable queda declarada en el estado.
# Requiere env: CANDIDATE_TAG, FAIL_MODE(true/false), ACR_NAME, IMAGE_NAME, RG, ACI_NAME,
#   TF_BACKEND_RG, TF_BACKEND_SA, TF_BACKEND_CONTAINER, TF_BACKEND_KEY
# Requiere: az login (OIDC en el workflow), terraform, docker, curl.
set -e
TF_DIR="infra/terraform"
LOGIN_SERVER="${ACR_NAME}.azurecr.io"
CANDIDATE="${LOGIN_SERVER}/${IMAGE_NAME}:${CANDIDATE_TAG}"
STABLE="${LOGIN_SERVER}/${IMAGE_NAME}:stable"
SHOULD_FAIL="$(echo "${FAIL_MODE:-false}" | tr '[:upper:]' '[:lower:]')"
LOGDIR="logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/deploy-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee "$LOG") 2>&1

echo "== CANDIDATE=$CANDIDATE =="
echo "== STABLE=$STABLE SHOULD_FAIL=$SHOULD_FAIL =="

tf_apply() { # $1=image $2=version $3=should_fail
  terraform -chdir="$TF_DIR" apply -auto-approve -input=false \
    -var="container_image=$1" -var="app_version=$2" -var="should_fail=$3"
}

wait_healthy() { # $1 = base_url
  for i in $(seq 1 30); do
    if curl -fsS --max-time 10 "$1/health" 2>/dev/null | tee /tmp/health.json; then
      echo "health OK (intento $i)"
      return 0
    fi
    echo "esperando app... intento $i/30"
    sleep 20
  done
  echo "health NUNCA respondio"
  return 1
}

# 1. Desplegar candidata via Terraform (state remoto compartido)
terraform -chdir="$TF_DIR" init -input=false \
  -backend-config="resource_group_name=${TF_BACKEND_RG:?}" \
  -backend-config="storage_account_name=${TF_BACKEND_SA:?}" \
  -backend-config="container_name=${TF_BACKEND_CONTAINER:?}" \
  -backend-config="key=${TF_BACKEND_KEY:?}"
tf_apply "$CANDIDATE" "$CANDIDATE_TAG" "$SHOULD_FAIL"
FQDN=$(terraform -chdir="$TF_DIR" output -raw container_fqdn)
BASE="http://${FQDN}:8080"
echo "== BASE=$BASE =="

# 2. Prueba de salud + funcional sencilla
HEALTH=0; FUNC=0
wait_healthy "$BASE" || HEALTH=1
echo "--- functional check $BASE/api/hello ---"
if [ "$HEALTH" -eq 0 ] && curl -fsS --max-time 15 "$BASE/api/hello" | grep -q "Hola"; then
  echo "functional OK"
else
  echo "functional FAIL"
  FUNC=1
fi

# 3. Decision: promover o rollback (ambos via Terraform, sin drift)
if [ "$HEALTH" -eq 0 ] && [ "$FUNC" -eq 0 ]; then
  echo "PROMOTE candidata -> stable"
  az acr login --name "$ACR_NAME"
  docker pull "$CANDIDATE"
  docker tag "$CANDIDATE" "$STABLE"
  docker push "$STABLE"
  # Deja el estado declarado en la nueva estable
  tf_apply "$STABLE" "stable" "false"
  echo "$STABLE <= $CANDIDATE" > stable-image.txt
  echo "DEPLOY OK - sin rollback"
else
  echo "ROLLBACK a $STABLE (via Terraform)"
  az container logs --resource-group "$RG" --name "$ACI_NAME" --container-name app \
    > "$LOGDIR/aci-failed-attempt.log" 2>&1 || true
  tf_apply "$STABLE" "stable" "false"
  FQDN=$(terraform -chdir="$TF_DIR" output -raw container_fqdn)
  BASE="http://${FQDN}:8080"
  wait_healthy "$BASE"
  curl -fsS --max-time 15 "$BASE/api/hello" | grep -q "Hola"
  echo "ROLLBACK OK - version estable restaurada. Evidencias: $LOG + $LOGDIR/aci-failed-attempt.log"
  exit 1  # fallo intencional: deja evidencia del intento fallido + rollback en el workflow
fi
