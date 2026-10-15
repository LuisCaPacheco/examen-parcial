# Taller 5 en Azure: RG dedicado + ACR Basic + ACI con identidad administrada + Log Analytics

resource "azurerm_resource_group" "taller" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

#checkov:skip=CKV_AZURE_139:Basic sin endpoint privado por costo del taller; admin OFF + identidad con AcrPull
#checkov:skip=CKV_AZURE_163:escaneo con Trivy en el pipeline (gate HIGH,CRITICAL) en vez de Defender
#checkov:skip=CKV_AZURE_164:content trust requiere Premium; se suple con Trivy como gate antes del push
#checkov:skip=CKV_AZURE_165:geo-replicacion Premium fuera de alcance/costo (1 region)
#checkov:skip=CKV_AZURE_166:cuarentena Premium; gate con Trivy antes del push
#checkov:skip=CKV_AZURE_167:retention Premium; tags :sha/:stable controlados por el workflow
#checkov:skip=CKV_AZURE_233:zone redundancy Premium fuera del costo del taller
#checkov:skip=CKV_AZURE_237:data endpoints dedicados requieren Premium
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

#checkov:skip=CKV_AZURE_98:ACI publico por diseno (URL publica es entregable); sin VNet por costo/complejidad
#checkov:skip=CKV_AZURE_245:ver CKV_AZURE_98 (misma razon)
#checkov:skip=CKV_AZURE_235:APP_VERSION y SHOULD_FAIL no son secretos (la version publicada es evidencia del taller)
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
    image  = var.container_image
    cpu    = var.container_cpu    # limite de recursos
    memory = var.container_memory # limite de recursos

    ports {
      port     = 8080
      protocol = "TCP"
    }

    environment_variables = {
      APP_VERSION = var.app_version
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
    server                    = azurerm_container_registry.app.login_server
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
