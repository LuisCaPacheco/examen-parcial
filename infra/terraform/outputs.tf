output "resource_group" {
  description = "RG dedicado del taller (separado del otro proyecto)"
  value       = azurerm_resource_group.taller.name
}

output "acr_login_server" {
  description = "Servidor del ACR"
  value       = azurerm_container_registry.app.login_server
}

output "container_fqdn" {
  description = "FQDN publico del ACI"
  value       = azurerm_container_group.app.fqdn
}

output "app_url" {
  description = "URL publica de la aplicacion (salud)"
  value       = "http://${azurerm_container_group.app.fqdn}:8080/health"
}
