variable "location" {
  description = "Region Azure (misma que el otro proyecto del equipo)"
  type        = string
  default     = "centralus"
}

variable "project" {
  description = "Nombre del proyecto (separado del otro proyecto del equipo)"
  type        = string
  default     = "examen-parcial"
}

variable "team" {
  description = "Equipo asignado"
  type        = string
  default     = "THE ODYSSEY"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "t5"
}

variable "resource_group_name" {
  description = "RG dedicado SOLO a este taller (no mezclar con el otro proyecto)"
  type        = string
  default     = "rg-examen-parcial-t5"
}

variable "acr_name" {
  description = "Nombre globalmente unico del ACR (solo minusculas y numeros, 5-50 chars). Si colisiona, cambiar el sufijo."
  type        = string
  default     = "exparcialt5ody01"
}

variable "dns_label" {
  description = "Etiqueta DNS unica del ACI en la region"
  type        = string
  default     = "examen-parcial-t5-ody"
}

variable "container_cpu" {
  description = "Limite CPU del contenedor (control de costo)"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Limite memoria GB del contenedor (control de costo)"
  type        = number
  default     = 1.0
}

variable "container_image" {
  description = "Imagen completa desplegada. Default: bootstrap publico para el primer apply (luego el workflow la mueve a ACR:stable/candidata)"
  type        = string
  default     = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
}

variable "app_version" {
  description = "Version reportada por la app (tag)"
  type        = string
  default     = "bootstrap"
}

variable "should_fail" {
  description = "Si true, la app responde 500 para simular version defectuosa (demo de rollback)"
  type        = bool
  default     = false
}

locals {
  common_tags = {
    Team        = var.team
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Taller      = "5-rollback"
  }
}
