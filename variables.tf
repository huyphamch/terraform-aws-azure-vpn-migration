variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default     = "azure-aws"
}

# Azure variables
variable "azure_location" {
  description = "Deployment Prefix"
  type        = string
  default     = "eastus"
}

variable "azure_vnet_prefix" {
  description = "Azure VNET prefix"
  type        = list(any)
  default     = ["172.10.0.0/16"]
}

variable "azure_gateway_subnet_prefix" {
  description = "GatewaySubnet Prefix"
  type        = list(any)
  default     = ["172.10.1.0/24"]
}

variable "azure_vm_subnet_prefix" {
  description = "Azure Test VM Subnet Prefix"
  type        = list(any)
  default     = ["172.10.100.0/24"]
}

variable "azure_vpn_gateway_sku" {
  description = "Azure Gateway SKU"
  type        = string
  default     = "Basic" #"VpnGw1"
}

variable "azure_vpn_gateway_asn" {
  description = "Azure Gateway BGP ASN"
  type        = string
  default     = "65515"
}

# AWS variables
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "aws_vpc_cidr_block" {
  description = "AWS VPC prefix"
  type        = string
  default     = "10.10.0.0/16"
}

variable "aws_vm_subnet_prefix" {
  description = "AWS Test VM Subnet Prefix"
  type        = string
  default     = "10.10.1.0/24"
}

variable "availability_zone" {
  description = "availability zone for the subnet"
  type        = string
  default     = "us-east-1a"
}

variable "aws_vpn_gateway_asn" {
  description = "AWS Gateway BGP ASN"
  type        = string
  default     = "64512"
}