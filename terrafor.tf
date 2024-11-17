[root@techm-tf-22 ~]# cd 
[root@techm-tf-22 ~]# mkdir azure_web/    ^C
[root@techm-tf-22 ~]# cd azure_web/
[root@techm-tf-22 azure_web]# vi vars.tf 
[root@techm-tf-22 azure_web]# cat vars.tf 
variable "azure" {
  type = map
  default = {
    client_id = "31495963-769f-4e7f-8ca3-3d050b098fb4",
    client_certificate_path = "/root/azure_access_11112024/mycert.pfx",
    tenant_id = "163a7f66-76d2-4e72-8d8f-013b1c7fa5e7",
    subscription_id = "67905f55-264e-4b7f-a516-d79f68610a45"
  }
}

variable "location" {
  type = string
  default = "Central India"
}

variable "prefix" {
  type = string
  default = "sagar-web"
}
[root@techm-tf-22 azure_web]# vi provider.tf 
[root@techm-tf-22 azure_web]# cat provider.tf 
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.10.0"
    }
  }
}

provider "azurerm" {
  features {}
  client_id                   = var.azure.client_id
  client_certificate_path     = var.azure.client_certificate_path
  tenant_id                   = var.azure.tenant_id
  subscription_id             = var.azure.subscription_id
}
[root@techm-tf-22 azure_web]# vi main.tf 
[root@techm-tf-22 azure_web]# cat main.tf 
resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_network_security_group" "example" {
  name                = "${var.prefix}-sg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "in2280"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "out2280"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "example" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "${var.prefix}-snet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "${var.prefix}-pubip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "example" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.example.id
  network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    #create shell script myscript.sh to install apache on ubuntu on local server
    command = "echo sudo apt-get update -y > myscript.sh ; echo sudo apt-get install apache2 -y >> myscript.sh ; echo sudo systemctl restart apache2 >> myscript.sh"
  }

  connection {
    type = "ssh"
    user = "adminuser"
    private_key = file("/root/.ssh/id_rsa")
    host = self.public_ip_address
  }

  provisioner "file" {
    #copy myscript.sh to ec2 instance
    source = "myscript.sh"
    destination = "/tmp/myscript.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /tmp/myscript.sh",
      "/bin/sh /tmp/myscript.sh"
    ]
  }
}
[root@techm-tf-22 azure_web]# vi out.tf 
[root@techm-tf-22 azure_web]# cat out.tf 
output "PublicIP" {
  value = azurerm_linux_virtual_machine.example.public_ip_address
}
[root@techm-tf-22 azure_web]# terraform init      
[root@techm-tf-22 azure_web]# terraform validate     
[root@techm-tf-22 azure_web]# terraform plan         
[root@techm-tf-22 azure_web]# terraform apply -auto-approve 
