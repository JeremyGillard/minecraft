output "server_ip_addr" {
  value = azurerm_linux_virtual_machine.vm0.public_ip_address
}