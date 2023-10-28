# Configure the Azure Provider
provider "azurerm" {
  subscription_id = "129cd528-d534-409f-8308-d62526e46bab"
  tenant_id       = "427dab8a-bad8-4ee1-a91e-1b653343cd1b"
  features {}
}

resource "azurerm_resource_group" "vpn-rg" {
  name     = "rg-${var.prefix}"
  location = var.azure_location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name
  address_space       = var.azure_vnet_prefix
}

resource "azurerm_subnet" "vpn-subnet" {
  name                 = "GatewaySubnet" # "vpn-subnet-${var.prefix}"
  resource_group_name  = azurerm_resource_group.vpn-rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.azure_gateway_subnet_prefix
}

resource "azurerm_public_ip" "VNet1GWpip" {
  name                = "pip-vpn-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_virtual_network_gateway" "VNet1GW" {
  name                = "vpn-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = var.azure_vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.VNet1GWpip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vpn-subnet.id
  }
}

# Create Local network gateway as VPN Endpoint (AWS) to configure the VPN settings
resource "azurerm_local_network_gateway" "AWSTunnel1ToInstance0" {
  name                = "lngw-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name
  gateway_address     = aws_vpn_connection.ToAzureInstance0.tunnel1_address
  address_space       = [aws_vpc.aws-vpc.cidr_block]
}

resource "azurerm_local_network_gateway" "AWSTunnel2ToInstance0" {
  name                = "lngw-standby-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name
  gateway_address     = aws_vpn_connection.ToAzureInstance0.tunnel2_address
  address_space       = [aws_vpc.aws-vpc.cidr_block]
}

# Create Site-2-Site VPN Connection between VNGW (Azure) and LNGW (AWS)
resource "azurerm_virtual_network_gateway_connection" "AWSTunnel1ToInstance0" {
  name                = "connection-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.VNet1GW.id
  local_network_gateway_id   = azurerm_local_network_gateway.AWSTunnel1ToInstance0.id

  shared_key = random_password.AWSTunnel1ToInstance0-PSK.result
}

resource "azurerm_virtual_network_gateway_connection" "AWSTunnel2ToInstance0" {
  name                = "connection-standby-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.VNet1GW.id
  local_network_gateway_id   = azurerm_local_network_gateway.AWSTunnel2ToInstance0.id

  shared_key = random_password.AWSTunnel2ToInstance0-PSK.result
}

# Create subnet for VM
resource "azurerm_subnet" "subnet-vm" {
  name                 = "subnet-vm-${var.prefix}"
  resource_group_name  = azurerm_resource_group.vpn-rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.azure_vm_subnet_prefix
}

# Create Security group and rules for VM
resource "azurerm_network_security_group" "nsg-vm" {
  name                = "nsg-vm-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name
}

resource "azurerm_network_security_rule" "nsg-ssh-vm-rule" {
  name                        = "ssh"
  description                 = "Allow SSH."
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*" #"${data.http.source_ip.response_body}/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vpn-rg.name
  network_security_group_name = azurerm_network_security_group.nsg-vm.name
}

resource "azurerm_network_security_rule" "nsg-aws-vm-rule" {
  name                        = "icmp"
  description                 = "Allow ICMP for AWS VPC resources"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.aws_vpc_cidr_block
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vpn-rg.name
  network_security_group_name = azurerm_network_security_group.nsg-vm.name
}

# Create Network interface with public IP for VM
resource "azurerm_public_ip" "pip-vm" {
  name                = "pip-vm-${var.prefix}"
  location            = azurerm_resource_group.vpn-rg.location
  resource_group_name = azurerm_resource_group.vpn-rg.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "nic-vm" {
  name                = "nic-vm-${var.prefix}"
  resource_group_name = azurerm_resource_group.vpn-rg.name
  location            = azurerm_resource_group.vpn-rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-vm.id
  }
}

# Apply Security group rules on network interface of VM
resource "azurerm_network_interface_security_group_association" "vm-sg-asoc" {
  network_interface_id      = azurerm_network_interface.nic-vm.id
  network_security_group_id = azurerm_network_security_group.nsg-vm.id
}

# Create Virtual Machine (VM)
resource "azurerm_linux_virtual_machine" "vm-linux" {
  name = "vm-linux-${var.prefix}"
  #  name                = "vm-windowws-${var.prefix}" 
  resource_group_name = azurerm_resource_group.vpn-rg.name
  location            = azurerm_resource_group.vpn-rg.location
  size                = "Standard_D2s_v3"

  # When an admin_password is specified disable_password_authentication must be set to false. ~> NOTE: One of either admin_password or admin_ssh_key must be specified.
  /*   admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  } */
  admin_username                  = "adminuser"
  admin_password                  = "Admin+123456"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic-vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  /*   source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  } */
}