# Evidencias — Taller 5 THE ODYSSEY (Azure)

Repo: https://github.com/LuisCaPacheco/examen-parcial
App (activa al momento de redactar): http://examen-parcial-t5-ody.centralus.azurecontainer.io:8080/health

## Runs clave (links directos)
- Infra en verde (fmt/validate/Checkov/plan/apply, crea RG+ACR+ACI): https://github.com/LuisCaPacheco/examen-parcial/actions/runs/38768667099
- Deploy sano en verde (build+Trivy+push+apply candidata+salud/funcional+PROMOTE a :stable): https://github.com/LuisCaPacheco/examen-parcial/actions/runs/38772777362
- Rollback en rojo-intencional (candidata SHOULD_FAIL=true, functional FAIL, reaplica :stable vía Terraform): https://github.com/LuisCaPacheco/examen-parcial/actions/runs/38774320384
- Verificación post-rollback: `curl /health` -> `{"status":"ok","version":"stable"}` y `/api/hello` -> `Hola THE ODYSSEY`.

## Artefactos en esta carpeta
- `run-infra-*/checkov-infra/`: SARIF de Checkov (checks Premium omitidos con justificación en `infra.yml` + `main.tf`).
- `run-exitoso-*/trivy-candidate/`: SARIF de Trivy limpio en HIGH/CRITICAL (imagen Alpine).
- `run-rollback-*/trivy-candidate/`: SARIF del intento fallido (la falla fue funcional, no de seguridad).

## Decisiones durante la ejecución (registro honesto)
1. OIDC: el subject presentado por GitHub traía sufijos `@id`; se igualó la federated credential al subject exacto reportado por AADSTS700213.
2. Terraform en CI necesitó `ARM_USE_OIDC=true` (el provider no puede usar el CLI logueado como SP).
3. El SP requirió rol `User Access Administrator` para crear el `AcrPull`.
4. Debian (trixie y bookworm) traía 55 HIGH sin fix → base Alpine (Trivy limpio, verificado local y en CI).
5. trivy-action v0.36.0 con `format: sarif` ignora `severity` salvo `limit-severities-for-sarif: true` (causaba exit 1 con solo MEDIUM/LOW).
6. Primer deploy: `:stable` no existía → bootstrap `aci-helloworld` + `decide image` en el workflow de infra.
7. Nota de timing: en el rollback, el primer poll de salud pudo alcanzar el contenedor previo al swap; la prueba funcional sí evaluó la candidata y disparó el rollback. Estado final verificado `:stable` sano.

## Destrucción (cierre para no generar costo PAYG)
Workflow manual `destroy-taller` (`.github/workflows/destroy.yml`): `terraform destroy` del RG completo.
Alternativa: `az group delete -n rg-examen-parcial-t5 --yes`.
El state (`rg-tfstate-examen`) se conserva para auditoría; borrarlo también si se desea: `az group delete -n rg-tfstate-examen --yes`.
