resource "azurerm_resource_group" "lab" {
  name     = "${var.resource_prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.resource_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "lab" {
  name                 = "k3s-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.30.1.0/24"]
}

resource "azurerm_public_ip" "lab" {
  name                = "${var.resource_prefix}-ip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "lab" {
  name                = "${var.resource_prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "SSH-Restricted"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-Lab"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "lab" {
  name                = "${var.resource_prefix}-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab.id
  }
}

resource "azurerm_network_interface_security_group_association" "lab" {
  network_interface_id      = azurerm_network_interface.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

resource "azurerm_linux_virtual_machine" "lab" {
  name                = "${var.resource_prefix}-vm"
  computer_name       = "k3s-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  zone                = var.vm_zone
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.lab.id
  ]

  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    k3s_version = var.k3s_version
  }))

  depends_on = [azurerm_network_interface_security_group_association.lab]
}
