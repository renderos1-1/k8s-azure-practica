variable "subscription_id" {
  type        = string
  description = "Identificador de la suscripcion Azure."
}

variable "location" {
  type        = string
  description = "Region utilizada para el despliegue; verificar politicas y capacidad de la suscripcion."
  default     = "mexicocentral"
}

variable "resource_prefix" {
  type        = string
  description = "Prefijo corto para los nombres de recursos."
  default     = "devops-k3s"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,17}$", var.resource_prefix))
    error_message = "Use entre 3 y 18 caracteres, comenzando con letra minuscula."
  }
}

variable "vm_size" {
  type        = string
  description = "Tamano de VM; el valor inicial se valido en Mexico Central, zona 1."
  default     = "Standard_B2s_v2"
}

variable "vm_zone" {
  type        = string
  description = "Zona de disponibilidad de la VM. Verificar restricciones del SKU antes de cambiarla."
  default     = "1"
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = "Usuario del servidor."
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Clave publica existente. Terraform expande ~ para Windows y Linux."
}

variable "ssh_source_cidr" {
  type        = string
  description = "IPv4 publica del estudiante con mascara /32; no usar 0.0.0.0/0."
  validation {
    condition     = can(cidrhost(var.ssh_source_cidr, 0)) && endswith(var.ssh_source_cidr, "/32")
    error_message = "Se requiere una direccion IP individual con mascara /32."
  }
}

variable "k3s_version" {
  type        = string
  description = "Version de K3s fijada para la practica."
  default     = "v1.35.2+k3s1"
}
