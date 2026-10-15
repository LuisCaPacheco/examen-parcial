# examen parcial — Taller 5: Recuperación automática ante un despliegue fallido
**Equipo: THE ODYSSEY — Azure pago por uso (RG dedicado, separado del otro proyecto)**

App contenerizada en Azure con rollback automático si la prueba de salud o funcional falla.
Todo cambio (sano o rollback) pasa por Terraform. Seguridad con Checkov y Trivy.

## 1. Arquitectura

```
GitHub (main)
 ├─ push app/** ──> workflow app.yml ──> build Docker -> Trivy HIGH,CRITICAL
 │                   -> push ACR :<sha> -> terraform apply (candidata)
 │                   -> curl /health + /api/hello
 │                   -> OK: push :stable + apply estable / FAIL: apply estable + logs + exit 1
 └─ push infra/** ─> workflow infra.yml -> fmt/validate/Checkov -> plan/apply

Azure eastus (tags Team=THE ODYSSEY, Project=examen-parcial, Env=t5)
 RG rg-examen-parcial-t5 (DEDICADO: no toca el otro proyecto)
 ACR Basic exparcialt5ody01 (admin OFF, scan implicito, :sha + :stable)
 ACI aci-examen-parcial-t5 (0.5 CPU / 1GB, identidad UserAssigned + rol AcrPull, probes /health)
 Log Analytics 30 dias (conserva logs del intento fallido)
```

Diagrama: ver `docs/arquitectura.mmd`. Costo controlado: ACR Basic + ACI 0.5/1GB + 1 región + retención 30 días.
**No se mezcla con el otro proyecto:** todo vive en `rg-examen-parcial-t5`; para borrar solo ese RG (ver §8).

## 2. Prueba local en contenedores (antes de gastar en Azure)

```bash
docker build -t odyssey-local -f Dockerfile .
docker run -d --name odyssey-ok -p 18080:8080 odyssey-local
curl http://localhost:18080/health      # {"status":"ok"}
curl http://localhost:18080/api/hello   # Hola THE ODYSSEY
docker rm -f odyssey-ok
# Simular version defectuosa (lo que dispara el rollback en la nube):
docker run -d --name odyssey-fail -p 18081:8080 -e SHOULD_FAIL=true odyssey-local
curl http://localhost:18081/health      # 500 fail (esperado)
docker rm -f odyssey-fail
```

## 3. Requisitos Azure (una sola vez)

```powershell
winget install Microsoft.AzureCLI
az login
az account show  # anota subscriptionId (SUB_ID) y tenantId (TENANT_ID)
```

**3.1. Storage para el state de Terraform** (los runners son efímeros; sin esto, infra y app se pisan):
```bash
az group create -n rg-tfstate-examen -l eastus
az storage account create -n stexparcialt5ody01 -g rg-tfstate-examen -l eastus --sku Standard_LRS
az storage container create -n tfstate --account-name stexparcialt5ody01
```
Si el storage name está ocupado (único global), elige otro y actualiza `TF_BACKEND_SA` en ambos workflows.
Igual con el ACR: `az acr check-name --name exparcialt5ody01` (si está tomado, cambia `acr_name` en `variables.tf` y `ACR_NAME` en `app.yml`).

**3.2. OIDC para GitHub (sin guardar passwords):**
```bash
APP_ID=$(az ad app create --display-name examen-parcial-t5-oidc --query appId -o tsv)
az ad sp create --id $APP_ID
az ad app federated-credential create --id $APP_ID --parameters '{"name":"github-main","issuer":"https://token.actions.githubusercontent.com","subject":"repo:LuisCaPacheco/examen-parcial:ref:refs/heads/main","audiences":["api://AzureADTokenExchange"]}'
az role assignment create --assignee $APP_ID --role Contributor --scope /subscriptions/<SUB_ID>
echo "CLIENT_ID=$APP_ID"
```

**3.3. Secrets del repo** (Settings > Secrets and variables > Actions, o con `gh secret set`):
- `AZURE_CLIENT_ID` = APP_ID, `AZURE_TENANT_ID` = TENANT_ID, `AZURE_SUBSCRIPTION_ID` = SUB_ID.

**3.4. Orden del primer despliegue:** primero corre el workflow `infra-validate-apply` (crea RG/ACR/ACI; el ACI queda en ImagePull hasta el primer push, es normal), luego `app-build-deploy-rollback` (publica `:sha`, la prueba y la promueve a `:stable`). Hay `concurrency` para que no se pisen.

## 4. Despliegue desde cero (orden)

```bash
cd infra/terraform
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan            # el ACI queda en ImagePull hasta el primer push (normal)
terraform output app_url          # http://<fqdn>:8080/health
# Primer estable: Actions > app-build-deploy-rollback > Run workflow (should_fail=false)
# o push a app/**. El workflow publica :sha, la prueba y la promueve a :stable.
```

## 5. Variables

| Variable | Dónde | Default |
|---|---|---|
| `location` | terraform | eastus |
| `resource_group_name` | terraform | rg-examen-parcial-t5 |
| `acr_name` | terraform + workflow env ACR_NAME | exparcialt5ody01 |
| `container_cpu` / `container_memory` | terraform | 0.5 / 1.0 (límite costo) |
| `container_image_tag` / `should_fail` | terraform (las mueve el workflow) | stable / false |
| `APP_VERSION` / `SHOULD_FAIL` | env del contenedor | tag / false |

## 6. Cómo probar / demos

- Sana: `curl http://<fqdn>:8080/health` -> `{"status":"ok"}` y `/api/hello` -> `Hola THE ODYSSEY`.
- Demo de rollback (requisito del taller 5): Actions > app-build-deploy-rollback > Run workflow > `should_fail=true`. Despliega candidata con `SHOULD_FAIL=true` vía Terraform, falla salud/funcional, reaplica `:stable` vía Terraform, guarda `logs/` + `az container logs` y falla el job a propósito. Esa es la evidencia.
- Cambio de app: edita `app/app.py` y push -> nuevo deploy automático.
- Cambio de infra: edita `infra/terraform/*` -> fmt/validate/Checkov/apply.

## 7. Evidencias (`docs/evidencias`)

URL repo, URL app, runs de Actions, SARIF Checkov/Trivy, `logs/deploy-*.log` + `aci-failed-attempt.log`, capturas `curl` antes/después. Plantilla en `docs/evidencias/PLANTILLA.md`.

## 8. Destruir (solo este taller, sin tocar el otro proyecto)

```bash
cd infra/terraform
terraform destroy
# o: az group delete -n rg-examen-parcial-t5 --yes  (borra TODO lo del taller y nada mas)
```

## 9. Decisiones, limitaciones y mejoras

Ver `docs/DECISIONES.md`.
