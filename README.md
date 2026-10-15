# examen parcial — Taller 5: Recuperación automática ante un despliegue fallido
**Equipo: THE ODYSSEY**

App contenerizada en AWS con rollback automático si la prueba de salud o funcional falla.
Infraestructura como código con Terraform + deploys con GitHub Actions + seguridad con Checkov y Trivy.

## 1. Arquitectura

```
GitHub (main)
 ├─ push app/** ──> workflow app.yml ──> build Docker -> Trivy HIGH,CRITICAL
 │                   -> push ECR :<sha> -> SSH a EC2 -> docker run candidata
 │                   -> curl /health + /api/hello
 │                   -> OK: retag :stable / FAIL: rollback a :stable + logs
 └─ push infra/** ─> workflow infra.yml -> fmt/validate/Checkov -> plan/apply

AWS us-east-1 (tags Team=THE ODYSSEY, Project=examen-parcial, Env=prod)
 VPC 10.5.0.0/16 + IGW + subnet publica + route table
 SG: 80,8080 abiertos / 22 solo ADMIN_IP
 EC2 t3.micro (8GB gp3 cifrado) + perfil IAM ECR-read-only + user_data (docker+nginx)
 ECR examen-parcial-app (scan-on-push, tags :sha y :stable)
```

Diagrama: ver `docs/arquitectura.mmd` (Mermaid). Costo controlado: t3.micro + 8GB + 1 AZ.

## 2. Requisitos

- Cuenta AWS + rol IAM para OIDC (`AWS_ROLE_TO_ASSUME`) o access keys.
- Secrets en GitHub (nunca en el repo — condición 8):
  - `AWS_ROLE_TO_ASSUME`, `EC2_HOST` (se actualiza con output de Terraform), `EC2_SSH_KEY`, `ADMIN_IP` (tu IP pública sin /32).
- Terraform >= 1.6 solo para cambios locales; el CI usa 1.9.0.

## 3. Despliegue desde cero

```bash
cd infra/terraform
terraform init
terraform fmt -check -recursive
terraform validate
# Checkov local (opcional): checkov -d .
terraform plan -var="admin_ip=$(curl -s ifconfig.me)/32" -out=tfplan
terraform apply tfplan
terraform output app_url   # -> http://<IP>/health
# Guarda la IP en el secret EC2_HOST de GitHub
# Primer estable:
docker build -t <ECR>:stable -f ../../Dockerfile ../..
docker push <ECR>:stable
echo "<ECR>:stable" > ../../stable-image.txt
```

## 4. Variables

| Variable | Dónde | Default |
|---|---|---|
| `aws_region` | infra/terraform | us-east-1 |
| `instance_type` | infra/terraform | t3.micro (límite costo) |
| `admin_ip` | secret ADMIN_IP | "" (SSH cerrado si vacío) |
| `APP_VERSION` / `SHOULD_FAIL` | Dockerfile / workflow input | stable / false |
| `AWS_REGION`, `ECR_REPO` | workflows env | us-east-1, examen-parcial-app |

## 5. Cómo probar

- Sana: `curl http://<IP>/health` -> `{"status":"ok"}` y `/api/hello` -> `Hola THE ODYSSEY`.
- Demo de rollback (requisito del taller 5): Actions > app-build-deploy-rollback > Run workflow > `should_fail=true`. El workflow despliega candidata con `SHOULD_FAIL=true`, falla health/ funcional, restaura `:stable` automáticamente, guarda `logs/` y marca el run en rojo-pero-recuperado. Esa es la evidencia.
- Cambio de app: edita `app/app.py` y push -> nuevo deploy automático.
- Cambio de infra: edita `infra/terraform/*` (ej. `instance_type`) -> fmt/validate/Checkov/apply.

## 6. Evidencias (carpeta docs/evidencias)

Guardar: URL repo, URL app, runs de Actions, SARIF de Checkov/Trivy, capturas del rollback, `logs/deploy-*.log`, outputs de Terraform. Plantilla en `docs/evidencias/PLANTILLA.md`.

## 7. Procedimiento de recuperación (resumen)

1. Workflow conserva `:stable` intacto hasta que la candidata pasa salud+funcional.
2. Si falla: `docker pull :stable && docker rm -f app && docker run :stable`, verifica `/health`, conserva log y falla el job a propósito para dejar evidencia.
3. Si pasa: `docker tag candidata :stable && push`, actualiza `stable-image.txt`.
4. Trivy bloquea ANTES de pushear si hay HIGH/CRITICAL; el fallo funcional es posterior y es el que dispara rollback (no confundir).

## 8. Destruir (capacidad de destrucción — 10% rúbrica)

```bash
cd infra/terraform
terraform destroy -var="admin_ip=$(curl -s ifconfig.me)/32"
# Verifica en consola AWS que no queden EC2/EIP/ECR (ECR tiene force_delete=true).
```

## 9. Decisiones, limitaciones y mejoras

Ver `docs/DECISIONES.md`.

## 10. Nota sobre tu Azure PAYG

Tu Azure pago-por-uso **sí sirve y no afecta** tu otro proyecto si usas otro resource group + tags + límites. Este taller se entrega en AWS (tu elección), así que no tocas Azure. Si quisieras portarlo, equivale a: ACR + ACI/Container Apps + Terraform azurerm.
