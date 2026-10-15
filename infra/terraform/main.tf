# Taller 5 en Azure: RG dedicado + ACR Basic + ACI con identidad administrada + Log Analytics
# checkov:skip=CKV_AZURE_139:ACR Basic sin replicacion geografica es intencional (bajo costo taller)

resource "azurerm_resource_group" "taller" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "app" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.taller.name
  location            = azurerm_resource_group.taller.location
  sku                 = "Basic" # limite de costo
  admin_enabled       = false   # sin credenciales admin: se usa identidad administrada
  tags                = local.common_tags
}

resource "azurerm_log_analytics_workspace" "app" {
  name                = "${var.project}-logs-${var.environment}"
  resource_group_name = azurerm_resource_group.taller.name
  location            = azurerm_resource_group.taller.location
  sku                 = "PerGB2018"
  retention_in_days   = 30 # limite de costo + conserva evidencias del intento fallido
  tags                = local.common_tags
}

# Identidad administrada asignada por usuario: el ACI hace pull del ACR sin guardar secretos
resource "azurerm_user_assigned_identity" "aci" {
  name                = "id-${var.project}-${var.environment}"
  resource_group_name = azurerm_resource_group.taller.name
  location            = azurerm_resource_group.taller.location
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "aci_acr_pull" {
  scope                = azurerm_container_registry.app.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aci.principal_id
}

resource "azurerm_container_group" "app" {
  name                = "aci-${var.project}-${var.environment}"
  resource_group_name = azurerm_resource_group.taller.name
  location            = azurerm_resource_group.taller.location
  ip_address_type     = "Public"
  dns_name_label      = var.dns_label
  os_type             = "Linux"
  restart_policy      = "Always"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aci.id]
  }

  container {
    name   = "app"
    image  = "${azurerm_container_registry.app.login_server}/app:${var.container_image_tag}"
    cpu    = var.container_cpu    # limite de recursos
    memory = var.container_memory # limite de recursos

    ports {
      port     = 8080
      protocol = "TCP"
    }

    environment_variables = {
      APP_VERSION = var.container_image_tag
      SHOULD_FAIL = var.should_fail ? "true" : "false"
    }

    liveness_probe {
      http_get {
        path   = "/health"
        port   = 8080
        scheme = "Http"
      }
      initial_delay_seconds = 15
      period_seconds        = 15
      failure_threshold     = 3
    }
    readiness_probe {
      http_get {
        path   = "/health"
        port   = 8080
        scheme = "Http"
      }
      initial_delay_seconds = 10
      period_seconds        = 10
      failure_threshold     = 3
    }
  }

  # Sin username/password: la identidad con rol AcrPull autentica contra el ACR
  image_registry_credential {
    server                 = azurerm_container_registry.app.login_server
    user_assigned_identity_id = azurerm_user_assigned_identity.aci.id
  }

  diagnostics {
    log_analytics {
      workspace_id  = azurerm_log_analytics_workspace.app.workspace_id
      workspace_key = azurerm_log_analytics_workspace.app.primary_shared_key
    }
  }

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.aci_acr_pull]
}
