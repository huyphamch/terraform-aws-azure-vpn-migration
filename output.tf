output "My_Public_IP" {
  description = "Pubic IP from my computer"
  value       = "${data.http.source_ip.response_body}/32"
}

# AWS output
output "ToAzureInstance0_Tunnel1_IP" {
  description = "To AzureInstance0 Tunnel 1 Outside IP address"
  value       = aws_vpn_connection.ToAzureInstance0.tunnel1_address
}

output "ToAzureInstance0_Tunnel2_IP" {
  description = "To AzureInstance0 Tunnel 2 Outside IP address"
  value       = aws_vpn_connection.ToAzureInstance0.tunnel2_address
}

# Azure output
output "AzureInstance0_IP" {
  description = "Azure Network Gateway Instance0 Public IP"
  value       = azurerm_public_ip.VNet1GWpip.ip_address
}
