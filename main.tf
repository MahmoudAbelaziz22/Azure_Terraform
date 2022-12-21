terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "oday-rg" {
  name     = "my-rg"
  location = var.rg_loction
  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_virtual_network" "oday-vn" {
  name                = "my-vn"
  resource_group_name = azurerm_resource_group.oday-rg.name
  location            = azurerm_resource_group.oday-rg.location
  address_space       = [var.vn_address_space]
  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_subnet" "oday-subnet" {
  name                 = "my-subnet"
  resource_group_name  = azurerm_resource_group.oday-rg.name
  virtual_network_name = azurerm_virtual_network.oday-vn.name
  address_prefixes     = [var.subnet_address]
}

resource "azurerm_network_security_group" "oday-sg" {
  name                = "my-sg"
  resource_group_name = azurerm_resource_group.oday-rg.name
  location            = azurerm_resource_group.oday-rg.location
  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_network_security_rule" "oday-sg-rule" {
  name                        = "my-sg-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.oday-rg.name
  network_security_group_name = azurerm_network_security_group.oday-sg.name
}

resource "azurerm_subnet_network_security_group_association" "oday-sga" {
  subnet_id                 = azurerm_subnet.oday-subnet.id
  network_security_group_id = azurerm_network_security_group.oday-sg.id
}

resource "azurerm_public_ip" "oday-ip" {
  name                = "my-ip"
  resource_group_name = azurerm_resource_group.oday-rg.name
  location            = azurerm_resource_group.oday-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "oday-nic" {
  name                = "my-nic"
  resource_group_name = azurerm_resource_group.oday-rg.name
  location            = azurerm_resource_group.oday-rg.location
  ip_configuration {

    name                          = "internal"
    subnet_id                     = azurerm_subnet.oday-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.oday-ip.id
  }
  tags = {
    "environment" = "dev"
  }

}

resource "azurerm_linux_virtual_machine" "oday-machine" {
  name                = "my-linux-machine"
  resource_group_name = azurerm_resource_group.oday-rg.name
  location            = azurerm_resource_group.oday-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.oday-nic.id,
  ]
  custom_data = filebase64(var.custom_data_file)
  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  provisioner "local-exec" {
    command = templatefile("ubuntu-ssh-script.tpl",{
       hostname= self.public_ip_address,
       user= "adminuser",
       identityfile= "~/.ssh/id_rsa"
    })
    interpreter = [
      "bash",
      "-c"
    ]
  }
}

data "azurerm_public_ip" "oday-ip-data" {
  name                = azurerm_public_ip.oday-ip.name
  resource_group_name = azurerm_resource_group.oday-rg.name
}

output "my-public-ip-address" {
  value= "${azurerm_linux_virtual_machine.oday-machine.name}:${data.azurerm_public_ip.oday-ip-data.ip_address}"
}