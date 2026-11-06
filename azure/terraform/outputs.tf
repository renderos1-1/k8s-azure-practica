output "public_ip" {
  description = "Direccion publica de la VM."
  value       = azurerm_public_ip.lab.ip_address
}

output "ssh_command" {
  description = "Comando de acceso valido en Windows y Linux."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.ip_address}"
}

# PRACTICA: agregar un output resource_group_name que muestre el grupo de recursos.
