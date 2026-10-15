# Matriz de cumplimiento — Taller 5 THE ODYSSEY
Segundo parcial 2724 · Infraestructura para TI · Recuperación automática ante un despliegue fallido (Azure)

Repo: https://github.com/LuisCaPacheco/examen-parcial

## 1. Condiciones obligatorias (12/12)

| # | Condición | Evidencia |
|---|---|---|
| 1 | Código publicado en GitHub | Este repositorio |
| 2 | Infraestructura como código con Terraform | `infra/terraform/` (RG, ACR, ACI, identidad, Log Analytics, backend remoto en Storage) |
| 3 | Workflows de GitHub Actions | `.github/workflows/app.yml`, `infra.yml`, `destroy.yml` |
| 4 | Distinguir cambios de app / infra / config | Filtros `paths:` en cada workflow; `concurrency` compartida para el state |
| 5 | Cambio en app → nueva versión desplegada | Push a `app/**` → build Docker + Trivy + push ACR + deploy. Run verde: `actions/runs/38772777362` |
| 6 | Cambio en infra → validación + apply Terraform | `fmt -check`, `validate`, Checkov, `plan/apply`. Run verde: `actions/runs/38768667099` |
| 7 | Al menos un control de seguridad | Checkov (SARIF) + Trivy (SARIF) + `fmt` + `validate` |
| 8 | Sin credenciales en el repo (Secrets u OIDC) | OIDC federado (`ARM_USE_OIDC`); solo Secrets `AZURE_*`, jamás claves en código |
| 9 | README con arquitectura, despliegue, variables, acceso, evidencias y destrucción | `README.md` + `docs/arquitectura.mmd` + `docs/evidencias/` + `destroy.yml` |
| 10 | Tags de equipo, proyecto y ambiente | `local.common_tags` en todo: Team=THE ODYSSEY, Project=examen-parcial, Env=t5 |
| 11 | Límites de recursos para controlar costos | ACI 0.5 CPU/1 GB, ACR Basic, Log Analytics 30 días |
| 12 | Demostrar cambio de app, cambio de infra, validación de seguridad y deploy exitoso | Runs 38772777362 (app), 38768667099 (infra), SARIFs, app verificada con `curl` |

## 2. Entregables comunes (10/11 + 1 N/A)

| # | Entregable | Estado |
|---|---|---|
| 1 | URL del repositorio | https://github.com/LuisCaPacheco/examen-parcial |
| 2 | URL pública o instrucciones de prueba | Estuvo viva y verificada (`http://examen-parcial-t5-ody.centralus.azurecontainer.io:8080`); destruida tras la demo para frenar el costo PAYG. Se recrea en ~8 min (workflow `infra` y luego `app`). Prueba local: `docker build -t x -f Dockerfile . && docker run -p 8080:8080 x` |
| 3 | Código de infraestructura | `infra/terraform/` |
| 4 | Dockerfile | `Dockerfile` (Alpine, Trivy HIGH/CRITICAL limpio) |
| 5 | Playbooks de Ansible | N/A — el punto 5 no lo exige ("cuando corresponda") |
| 6 | Workflows de GitHub Actions | `.github/workflows/` (3 archivos) |
| 7 | README técnico y diagrama | `README.md` + `docs/arquitectura.mmd` |
| 8 | Evidencias de Checkov y Trivy | `docs/evidencias/*/checkov-infra/` y `trivy-candidate/` (SARIF) |
| 9 | Evidencia de cambio de app desplegado | Run 38772777362: candidata probada y promovida a `:stable` |
| 10 | Evidencia de cambio de infra aplicado | Run 38768667099 + demo de rollback 38774320384 (reaplicó `:stable` vía Terraform) |
| 11 | Decisiones, limitaciones y mejoras | `docs/DECISIONES.md` + `docs/evidencias/EVIDENCIAS.md` |

## 3. Rúbrica

| Criterio | Peso | Cómo se cubre |
|---|---|---|
| Infraestructura como código | 20% | Terraform + backend remoto + toda mutación (deploy y rollback) vía `apply` |
| Automatización CI/CD | 25% | Pipelines separados, gates de seguridad, rollback automático, workflow de destrucción |
| Contenedores y despliegue | 15% | Docker + ACR (`:sha`/`:stable`) + ACI con probes `/health` |
| Seguridad y credenciales | 15% | OIDC, Trivy como gate, Checkov, ACR sin admin, identidad administrada + AcrPull |
| Funcionamiento en la nube | 15% | App verificada en vivo (`/health` y `/api/hello` con `curl`) |
| Documentación, demo y destrucción | 10% | README, diagrama, evidencias, demo de rollback y `destroy-taller` ejecutado |

## 4. Demo de sustentación (guion, ~10 min)
1. Mostrar repo + workflows + SARIFs (2 min).
2. Disparar `infra-validate-apply` y luego `app-build-deploy-rollback` (8 min, o mostrar runs ya verdes).
3. `curl` a `/health` y `/api/hello` en vivo.
4. Disparar `app-build-deploy-rollback` con `should_fail=true`: falla funcional → rollback a `:stable` → `curl` sano.
5. Opcional: `destroy-taller` para cerrar sin costos.
