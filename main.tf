// ACE-ops Core Aviatrix Infrastructure

# Private Key creation
resource "tls_private_key" "avtx_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "avtx_priv_key" {
  content         = tls_private_key.avtx_key.private_key_pem
  filename        = "avtx_priv_key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "aws_west1_key" {
  provider   = aws.west
  key_name   = var.spoke1_ec2_key_name
  public_key = tls_private_key.avtx_key.public_key_openssh
}

resource "aws_key_pair" "aws_west2_key" {
  provider   = aws.west2
  key_name   = var.onprem_ec2_key_name
  public_key = tls_private_key.avtx_key.public_key_openssh
}

# Multi-Cloud Segmentation
resource "aviatrix_segmentation_security_domain" "BU2" {
  domain_name = "BU2"
}

resource "aviatrix_segmentation_security_domain" "BU1" {
  domain_name = "BU1"
}

/* resource "aviatrix_segmentation_security_domain_connection_policy" "BU1_BU2" {
  domain_name_1 = "BU1"
  domain_name_2 = "BU2"
  depends_on = [aviatrix_segmentation_security_domain.BU1, aviatrix_segmentation_security_domain.BU2]
} */

# AWS Transit Modules
module "aws_transit_1" {
  # source = "git::https://github.com/terraform-aviatrix-modules/terraform-aviatrix-aws-transit-firenet.git?ref=v2.0.2"
  source = "git::https://github.com/terraform-aviatrix-modules/terraform-aviatrix-aws-transit-firenet.git?ref=1f2eb38bd21201ca66dc9377fe7853cf1b4ad58c"
  # source                 = "terraform-aviatrix-modules/aws-transit-firenet/aviatrix"
  # version                = "3.0.3"
  account                              = var.aws_account_name
  region                               = var.aws_transit1_region
  name                                 = var.aws_transit1_name
  cidr                                 = var.aws_transit1_cidr
  ha_gw                                = var.ha_enabled
  prefix                               = var.prefix
  suffix                               = var.suffix
  egress_enabled                       = false
  insane_mode                          = false
  instance_size                        = var.aws_transit_instance_size
  enable_segmentation                  = true
  keep_alive_via_lan_interface_enabled = true
  firewall_image                       = var.aws_firewall_image
  firewall_image_version               = var.aws_firewall_image_version
}

# AWS Spoke Modules
module "aws_spoke_1" {
  source          = "terraform-aviatrix-modules/aws-spoke/aviatrix"
  version         = "3.0.0"
  account         = var.aws_account_name
  region          = var.aws_spoke1_region
  name            = var.aws_spoke1_name
  cidr            = var.aws_spoke1_cidr
  ha_gw           = var.ha_enabled
  prefix          = var.prefix
  suffix          = var.suffix
  security_domain = aviatrix_segmentation_security_domain.BU1.domain_name
  transit_gw      = module.aws_transit_1.transit_gateway.gw_name
}

module "aws_spoke_2" {
  source          = "terraform-aviatrix-modules/aws-spoke/aviatrix"
  version         = "3.0.0"
  account         = var.aws_account_name
  region          = var.aws_spoke2_region
  name            = var.aws_spoke2_name
  cidr            = var.aws_spoke2_cidr
  ha_gw           = var.ha_enabled
  prefix          = var.prefix
  suffix          = var.suffix
  security_domain = aviatrix_segmentation_security_domain.BU2.domain_name
  transit_gw      = module.aws_transit_1.transit_gateway.gw_name
}

# Azure Transit Module
module "azure_transit_1" {
  source              = "terraform-aviatrix-modules/azure-transit/aviatrix"
  version             = "3.0.0"
  ha_gw               = var.ha_enabled
  account             = var.azure_account_name
  region              = var.azure_transit1_region
  name                = var.azure_transit1_name
  cidr                = var.azure_transit1_cidr
  prefix              = var.prefix
  suffix              = var.suffix
  enable_segmentation = true
}

# Azure Spoke 1 
module "azure_spoke_1" {
  source          = "terraform-aviatrix-modules/azure-spoke/aviatrix"
  version         = "3.0.0"
  account         = var.azure_account_name
  region          = var.azure_spoke1_region
  name            = var.azure_spoke1_name
  cidr            = var.azure_spoke1_cidr
  prefix          = var.prefix
  suffix          = var.suffix
  instance_size   = var.azure_spoke_instance_size
  ha_gw           = var.ha_enabled
  security_domain = aviatrix_segmentation_security_domain.BU1.domain_name
  transit_gw      = module.azure_transit_1.transit_gateway.gw_name
}

# Azure Spoke 2
module "azure_spoke_2" {
  source          = "terraform-aviatrix-modules/azure-spoke/aviatrix"
  version         = "3.0.0"
  account         = var.azure_account_name
  region          = var.azure_spoke2_region
  name            = var.azure_spoke2_name
  cidr            = var.azure_spoke2_cidr
  prefix          = var.prefix
  suffix          = var.suffix
  instance_size   = var.azure_spoke_instance_size
  ha_gw           = var.ha_enabled
  security_domain = aviatrix_segmentation_security_domain.BU2.domain_name
  transit_gw      = module.azure_transit_1.transit_gateway.gw_name
}

# GCP Transit Module
module "gcp_transit_1" {
  # source = "git::https://github.com/terraform-aviatrix-modules/terraform-aviatrix-gcp-transit.git?ref=v3.0.0"
  source              = "terraform-aviatrix-modules/gcp-transit/aviatrix"
  version             = "3.0.0"
  account             = var.gcp_account_name
  region              = var.gcp_transit1_region
  name                = var.gcp_transit1_name
  cidr                = var.gcp_transit1_cidr
  prefix              = var.prefix
  suffix              = var.suffix
  enable_segmentation = true
  ha_gw               = var.ha_enabled
}

# Aviatrix GCP Spoke 1
module "gcp_spoke_1" {
  # source = "git::https://github.com/terraform-aviatrix-modules/terraform-aviatrix-gcp-spoke.git?ref=v3.0.0"
  source          = "terraform-aviatrix-modules/gcp-spoke/aviatrix"
  version         = "3.0.0"
  account         = var.gcp_account_name
  region          = var.gcp_spoke1_region
  name            = var.gcp_spoke1_name
  cidr            = var.gcp_spoke1_cidr
  prefix          = var.prefix
  suffix          = var.suffix
  ha_gw           = var.ha_enabled
  security_domain = aviatrix_segmentation_security_domain.BU1.domain_name
  transit_gw      = module.gcp_transit_1.transit_gateway.gw_name
}

# Create another Gateway in the Azure Spoke for Egress FQDN (later on)
resource "aviatrix_gateway" "ace-azure-egress-fqdn" {
  cloud_type   = 8
  account_name = var.azure_account_name
  gw_name      = "${var.azure_spoke2_name}-egress"
  vpc_id       = module.azure_spoke_2.vnet.vpc_id
  vpc_reg      = var.azure_spoke2_region
  gw_size      = var.azure_spoke_instance_size
  # subnet       = var.azure_spoke2_cidr
  # subnet       = module.azure_spoke_2.vnet.public_subnets[0].name
  subnet = module.azure_spoke_2.vnet.public_subnets[0].cidr
}

# Multi region Multi-Cloud transit peering
module "transit-peering" {
  source           = "terraform-aviatrix-modules/mc-transit-peering/aviatrix"
  version          = "1.0.2"
  transit_gateways = [module.gcp_transit_1.transit_gateway.gw_name, module.azure_transit_1.transit_gateway.gw_name, module.aws_transit_1.transit_gateway.gw_name]
}

# Transit FireNet Spoke Inspection Policy
resource "aviatrix_transit_firenet_policy" "transit_firenet_policy_1" {
    # transit_firenet_gateway_name = "ace-aws-eu-west-1-transit1"
    transit_firenet_gateway_name = var.aws_transit1_name
    # inspected_resource_name = "SPOKE:ace-aws-eu-west-1-spoke1"
    inspected_resource_name = "SPOKE:${var.aws_spoke1_name}"
}

resource "aviatrix_transit_firenet_policy" "transit_firenet_policy_2" {
    # transit_firenet_gateway_name = "ace-aws-eu-west-1-transit1"
    transit_firenet_gateway_name = var.aws_transit1_name
    # inspected_resource_name = "SPOKE:ace-aws-eu-west-1-spoke2"
    inspected_resource_name = "SPOKE:${var.aws_spoke2_name}"
}


# Create an Aviatrix Site2cloud Connection
resource "aviatrix_site2cloud" "s2c-onprem-partner" {
  vpc_id                     = "${module.gcp_spoke_1.vpc.vpc_id}~-~${var.account_name_in_gcp}"
  connection_name            = "ACE-CALL-CENTER"
  connection_type            = "mapped"
  remote_gateway_type        = "generic"
  tunnel_type                = "route"
  primary_cloud_gateway_name = module.gcp_spoke_1.vpc.name
  remote_gateway_ip          = aws_instance.ace-onprem-partner-csr.public_ip
  pre_shared_key             = var.ace_password
  local_subnet_cidr          = "172.16.211.0/24"
  local_subnet_virtual       = "192.168.1.0/24"
  remote_subnet_cidr         = "172.16.211.0/24"
  remote_subnet_virtual      = "192.168.2.0/24"
}

# Create an Aviatrix Gateway FQDN filter
/* resource "aviatrix_fqdn" "fqdn_filter" {
  fqdn_tag     = "ace-ops-tag"
  fqdn_enabled = true
  fqdn_mode    = "white"
  gw_filter_tag_list {
    gw_name        = aviatrix_gateway.ace-azure-egress-fqdn.gw_name
  }
  domain_names {
    fqdn  = "ubuntu.com"
    proto = "tcp"
    port  = "443"
    action = "Allow"
  }
  domain_names {
    fqdn  = "netjoints.com"
    proto = "tcp"
    port  = "443"
  }
} */

/* output "gcp_spoke_1_vpc" {
  value = module.gcp_spoke_1.vpc
}

output "gcp_spoke_1_aviatrix_spoke_gateway" {
  value = module.gcp_spoke_1.spoke_gateway
} */

output "firewall_public_ip" {
  value = module.aws_transit_1.aviatrix_firewall_instance[0].public_ip
}

/* output "firewall_public_ip" {
  value = module.azure_transit_1.aviatrix_firewall_instance[0].public_ip
} */

/* output "SPOKE2_VNET" {
  value = module.azure_spoke_2.vnet
} */




########################################################################

resource "aviatrix_transit_external_device_conn" "s2c-onprem-dc" {
  vpc_id             = module.aws_transit_1.vpc.vpc_id
  connection_name    = "ACE-ONPREM-DC"
  gw_name            = module.aws_transit_1.vpc.name
  remote_gateway_ip  = aws_instance.ace-onprem-dc-csr.public_ip
  pre_shared_key     = var.ace_password
  connection_type    = "bgp"
  direct_connect     = false
  bgp_local_as_num   = "65011"
  bgp_remote_as_num  = "65012"
  ha_enabled         = false
  local_tunnel_cidr  = "169.254.74.130/30"
  remote_tunnel_cidr = "169.254.74.129/30"
  custom_algorithms  = false
}

resource "aviatrix_segmentation_security_domain_association" "test_segmentation_security_domain_association" {
  # transit_gateway_name = module.aws_transit_1.transit_gateway.name
  # transit_gateway_name = module.aws_transit_1
  transit_gateway_name = var.aws_transit1_name
  security_domain_name = "BU1"
  attachment_name      = aviatrix_transit_external_device_conn.s2c-onprem-dc.connection_name
}