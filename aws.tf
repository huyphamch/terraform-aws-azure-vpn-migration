provider "aws" {
  region = var.aws_region
}

# Create VPC
resource "aws_vpc" "aws-vpc" {

  cidr_block = var.aws_vpc_cidr_block

  tags = {
    Name = "vpc-${var.prefix}"
  }
}

# Create Internet gateway and attach gateway to VPC to let EC2 instances access the internet
resource "aws_internet_gateway" "igw-vpn" {
  vpc_id = aws_vpc.aws-vpc.id

  tags = {
    Name = "igw-vpn-${var.prefix}"
  }
}

# Create Subnet and attach subnet to route table
resource "aws_subnet" "vpn-subnet" {
  vpc_id                  = aws_vpc.aws-vpc.id
  cidr_block              = var.aws_vm_subnet_prefix
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-vpn-${var.prefix}"
  }
}

resource "aws_route_table" "vpn-route-table" {
  vpc_id = aws_vpc.aws-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-vpn.id
  }

  tags = {
    Name = "vpn-route-table"
  }
}

resource "aws_route_table_association" "vpn-route-table-asoc" {
  subnet_id      = aws_subnet.vpn-subnet.id
  route_table_id = aws_route_table.vpn-route-table.id
}

# Create Customer Gateway as VPN Endpoint to configure the VPN settings
resource "aws_customer_gateway" "ToAzureInstance0" {
  bgp_asn    = var.azure_vpn_gateway_asn
  ip_address = azurerm_public_ip.VNet1GWpip.ip_address
  type       = "ipsec.1"

  tags = {
    Name = "cgw-${var.prefix}"
  }
}

# Create VPN Gateway and attach gateway to VPC and route table
resource "aws_vpn_gateway" "vpn-gw" {
  vpc_id            = aws_vpc.aws-vpc.id
  availability_zone = var.availability_zone

  tags = {
    Name = "vpg-${var.prefix}"
  }
}

# Add a route to send traffic from AWS to Azure
resource "aws_vpn_gateway_route_propagation" "main" {
  vpn_gateway_id = aws_vpn_gateway.vpn-gw.id
  route_table_id = aws_route_table.vpn-route-table.id
}

# Assign vpn gateway to route table
resource "aws_route" "incoming-route" {
  destination_cidr_block = element(var.azure_vm_subnet_prefix, 0)
  gateway_id             = aws_vpn_gateway.vpn-gw.id
  route_table_id         = aws_route_table.vpn-route-table.id
}

# Create Site-2-Site VPN Connection between VPG (AWS) and CGW (Azure)
resource "aws_vpn_connection" "ToAzureInstance0" {
  vpn_gateway_id      = aws_vpn_gateway.vpn-gw.id
  customer_gateway_id = aws_customer_gateway.ToAzureInstance0.id
  type                = "ipsec.1"
  static_routes_only  = true

  # tunnel1_inside_cidr   = azurerm_subnet.vpn-subnet.address_prefixes
  # tunnel2_inside_cidr   = azurerm_subnet.vpn-subnet.address_prefixes
  tunnel1_preshared_key = random_password.AWSTunnel1ToInstance0-PSK.result
  tunnel2_preshared_key = random_password.AWSTunnel2ToInstance0-PSK.result

  tags = {
    Name = "vpn-${var.prefix}"
  }
}

# Add a static IP prefix route between a VPN connection and a customer gateway.
resource "aws_vpn_connection_route" "office" {
  destination_cidr_block = element(var.azure_vm_subnet_prefix, 0)
  vpn_connection_id      = aws_vpn_connection.ToAzureInstance0.id
}

# Create Amazon Linux-Apache2 EC2-template for auto-scaling
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# Create Amazon Linux-Apache2 EC2-instances
# 9. Create security group to allow port: Http, Https, SSH, RDP
resource "aws_security_group" "security-group-web" {
  name        = "Allow_inbound_traffic"
  description = "Allow ssh and Azure VNet resources inbound traffic"
  vpc_id      = aws_vpc.aws-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #["${data.http.source_ip.response_body}/32"]
  }

  ingress {
    description = "ICMP into VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = azurerm_virtual_network.vnet.address_space
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security-group-web"
  }
}

resource "aws_instance" "web-linux" {
  ami                         = data.aws_ami.app_ami.id #"ami-03a6eaae9938c858c" # windows: "ami-0be0e902919675894"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.key_pair.key_name
  subnet_id                   = aws_subnet.vpn-subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.security-group-web.id]

  tags = {
    Name = "ec2-linux"
  }
}