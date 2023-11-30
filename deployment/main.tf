resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.project_id}"
  location = local.resource_location
}

############## Network Config ##############

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${local.project_id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "MinecraftBedrock"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "19132"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.project_id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "sub-0"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "vm-${local.project_id}-0-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "vm-${local.project_id}-0-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    primary                       = true
    name                          = "external"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg-assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "nic-assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

############## Storage Config ##############

resource "azurerm_managed_disk" "disk" {
  name                  = "vm-${local.project_id}-0-disk"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  storage_account_type  = "StandardSSD_LRS"
  create_option         = "Empty"
  disk_size_gb          = "10"
  network_access_policy = "DenyAll"
}

########### VirtualMachine Config ###########

resource "azurerm_linux_virtual_machine" "vm0" {
  name                = "vm-${local.project_id}-0"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2ms"
  admin_username      = var.username

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "vm-${local.project_id}-0-osdisk"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = "30"
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "datadiskassoc" {
  managed_disk_id    = azurerm_managed_disk.disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm0.id
  lun                = "0"
  caching            = "ReadWrite"
}