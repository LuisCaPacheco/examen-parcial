# Decisiones, limitaciones y mejoras — THE ODYSSEY (Azure)

## Decisiones
- Azure pago por uso existente: RG dedicado `rg-examen-parcial-t5` para no mezclar con el otro proyecto.
- ACI + ACR Basic (no AKS/Container Apps): demo en 1 día, costo mínimo, rollback legible por el jurado.
- Identidad administrada UserAssigned + rol AcrPull: ACR con `admin_enabled=false`, cero secretos de registry en repo o workflows.
- Todo deploy y todo rollback pasan por `terraform apply` (vars `container_image_tag`/`should_fail`): sin drift, la estable queda declarada en el estado.
- Flask minimalista con `SHOULD_FAIL` para demo controlada. Probes `/health` en ACI + checks del workflow.
- Dos workflows separados por `paths:` (condición 4). OIDC con federated credentials (condición 8).
- Tags en todo + 0.5 CPU/1GB + Log Analytics 30 días (condiciones 10 y 11).
- Trivy gatea ANTES del push; salud/funcional gatean DESPUÉS del deploy.

## Limitaciones
- 1 región, 1 réplica, sin HTTPS propio (mejorable con App Gateway + cert).
- ACI tarda 1-3 min en arrancar: el script espera hasta ~10 min.
- Backend Terraform local (mejorable a Storage Account + lock para equipo).

## Mejoras futuras
- Container Apps con revisiones y tráfico canary, ACR lifecycle policy, alertas + dashboard, staging slot.
