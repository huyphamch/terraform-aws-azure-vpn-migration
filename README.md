## Description
A fintech firm has a global client. To ensure the availability of its services. The chief solutions architect has suggested keeping the services running on a multi cloud environment. They want to deploy app resources in Azure and AWS and allow them to communicate with each other without exposing them to public access as the data on these resources will be confidential and should not be compromised.

## Objectives
Create an architecture and the step-by-step guide to provide a solution
for this scenario.

<br />Features of the project:
• Virtual network and subnet in Azure
• Virtual private cloud in AWS
• Gateways in AWS and Azure

## Solution
![Image](https://github.com/huyphamch/terraform-aws-azure-vpn-migration/blob/main/diagrams/IT-Architecture.png)
<br />1. Creating a Virtual Network and a subnet in Azure
<br />2. Creating a Virtual Network Gateway
<br />3. Creating a Virtual Private Cloud in AWS
<br />4. Creating a Gateways in AWS
<br />5. Creating a connection in Azure Virtual Network Gateway
<br />6. Testing the connection

## Usage
<br /> 1. Open terminal
<br /> 2. Before you can execute the terraform script, your need to create your access key and configure your AWS environment first.
<br /> aws configure
<br /> AWS Access Key ID: See IAM > Security credentials > Access keys > Create access key
<br /> AWS Secret Access Key: See IAM > Security credentials > Access keys > Create access key
<br /> Default region name: us-east-1
<br /> Default output format: json
<br /> 3. Before you can execute the terraform script, your need to configure your Azure environment first.
<br /> az login --user <myAlias@myCompany.onmicrosoft.com> --password <myPassword>
<br /> Update subscription_id in main.tf (az account subscription list)
<br /> Update tenant_id in main.tf (az account tenant list)
<br /> 4. Now you can apply the terraform changes.
<br /> terraform init
<br /> terraform apply --auto-approve
<br /> 5. At the end you can cleanup the created AWS resources.
<br /> terraform destroy --auto-approve
