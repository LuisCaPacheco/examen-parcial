# Evidencias a recolectar
- [ ] URL repo GitHub
- [ ] URL app (`terraform output app_url`)
- [ ] Run infra.yml en verde (fmt/validate/Checkov/apply)
- [ ] Run app.yml en verde (deploy sano + promote a :stable)
- [ ] Run app.yml con should_fail=true en rojo + log de ROLLBACK OK
- [ ] SARIF Trivy + SARIF Checkov (artefactos)
- [ ] `logs/deploy-*.log` del intento fallido
- [ ] Captura `curl /health` antes/después del rollback
- [ ] `terraform destroy` exitoso
