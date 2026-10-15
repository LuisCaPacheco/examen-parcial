variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto"
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
  default     = "prod"
}

variable "admin_ip" {
  description = "IP autorizada para SSH (CIDR). Ej: 1.2.3.4/32. Obligatorio para cumplir condicion de limitar acceso administrativo."
  type        = string
  # Por defecto cerrado; el workflow falla si no se define por secret/var
  default = ""
}

variable "instance_type" {
  description = "Tipo de instancia (limite de costo)"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Puerto de la app"
  type        = number
  default     = 8080
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
