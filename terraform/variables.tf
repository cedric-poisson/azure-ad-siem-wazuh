variable "my_ip" {
  description = "IP publique autorisée à accéder aux VMs (WinRM/RDP)"
  type        = string
}
variable "admin_username" {
  description = "Nom d'utilisateur admin local des VMs Windows"
  type        = string
}

variable "admin_password" {
  description = "Mot de passe admin local des VMs Windows"
  type        = string
  sensitive   = true
}