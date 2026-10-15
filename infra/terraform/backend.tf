# Estado remoto en Storage Account (compartido por los runners efimeros de GitHub Actions).
# Sin esto, cada workflow usaria un state local distinto y se pisarian.
# Se configura con -backend-config en el init (ver workflows y scripts/deploy_with_rollback.sh).
terraform {
  backend "azurerm" {}
}
