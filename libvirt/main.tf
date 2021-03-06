module "local_execution" {
  source  = "../generic_modules/local_exec"
  enabled = var.pre_deployment
}

# This locals entry is used to store the IP addresses of all the machines.
# Autogenerated addresses example based in 19.168.135.0/24
# Iscsi server: 19.168.135.4
# Monitoring: 19.168.135.5
# Hana ips: 19.168.135.10, 19.168.135.11
# Hana cluster vip: 19.168.135.12
# DRBD ips: 19.168.135.20, 19.168.135.21
# DRBD cluster vip: 19.168.135.22
# Netweaver ips: 19.168.135.30, 19.168.135.31, 19.168.135.32, 19.168.135.33
# Netweaver virtual ips: 19.168.135.34, 19.168.135.35, 19.168.135.36, 19.168.135.37
# If the addresses are provided by the user they will always have preference
locals {
  iscsi_srv_ip      = var.iscsi_srv_ip != "" ? var.iscsi_srv_ip : cidrhost(local.iprange, 4)
  monitoring_srv_ip = var.monitoring_srv_ip != "" ? var.monitoring_srv_ip : cidrhost(local.iprange, 5)

  hana_ip_start    = 10
  hana_ips         = length(var.hana_ips) != 0 ? var.hana_ips : [for ip_index in range(local.hana_ip_start, local.hana_ip_start + var.hana_count) : cidrhost(local.iprange, ip_index)]
  hana_cluster_vip = var.hana_cluster_vip != "" ? var.hana_cluster_vip : cidrhost(local.iprange, local.hana_ip_start + var.hana_count)

  # 2 is hardcoded for drbd because we always deploy 2 machines
  drbd_ip_start    = 20
  drbd_ips         = length(var.drbd_ips) != 0 ? var.drbd_ips : [for ip_index in range(local.drbd_ip_start, local.drbd_ip_start + 2) : cidrhost(local.iprange, ip_index)]
  drbd_cluster_vip = var.drbd_cluster_vip != "" ? var.drbd_cluster_vip : cidrhost(local.iprange, local.drbd_ip_start + 2)

  # 4 is hardcoded for netweaver because we always deploy 4 machines
  netweaver_ip_start    = 30
  netweaver_ips         = length(var.netweaver_ips) != 0 ? var.netweaver_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + 4) : cidrhost(local.iprange, ip_index)]
  netweaver_virtual_ips = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + 4) : cidrhost(local.iprange, ip_index + 4)]
}

module "iscsi_server" {
  source                 = "./modules/iscsi_server"
  iscsi_count            = var.shared_storage_type == "iscsi" ? 1 : 0
  source_image           = var.iscsi_source_image
  volume_name            = var.iscsi_source_image != "" ? "" : (var.iscsi_volume_name != "" ? var.iscsi_volume_name : local.generic_volume_name)
  vcpu                   = var.iscsi_vcpu
  memory                 = var.iscsi_memory
  bridge                 = "br0"
  storage_pool           = var.storage_pool
  isolated_network_id    = local.internal_network_id
  isolated_network_name  = local.internal_network_name
  iscsi_srv_ip           = local.iscsi_srv_ip
  iscsidev               = "/dev/vdb"
  iscsi_disks            = var.iscsi_disks
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  qa_mode                = var.qa_mode
  provisioner            = var.provisioner
  background             = var.background
}

module "hana_node" {
  source                 = "./modules/hana_node"
  name                   = "hana"
  source_image           = var.hana_source_image
  volume_name            = var.hana_source_image != "" ? "" : (var.hana_volume_name != "" ? var.hana_volume_name : local.generic_volume_name)
  hana_count             = var.hana_count
  vcpu                   = var.hana_node_vcpu
  memory                 = var.hana_node_memory
  bridge                 = "br0"
  isolated_network_id    = local.internal_network_id
  isolated_network_name  = local.internal_network_name
  storage_pool           = var.storage_pool
  host_ips               = local.hana_ips
  hana_inst_folder       = var.hana_inst_folder
  hana_inst_media        = var.hana_inst_media
  hana_platform_folder   = var.hana_platform_folder
  hana_sapcar_exe        = var.hana_sapcar_exe
  hdbserver_sar          = var.hdbserver_sar
  hana_extract_dir       = var.hana_extract_dir
  hana_disk_size         = var.hana_node_disk_size
  hana_fstype            = var.hana_fstype
  hana_cluster_vip       = local.hana_cluster_vip
  shared_storage_type    = var.shared_storage_type
  sbd_disk_id            = module.sbd_disk.id
  iscsi_srv_ip           = module.iscsi_server.output_data.private_addresses.0
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  qa_mode                = var.qa_mode
  hwcct                  = var.hwcct
  devel_mode             = var.devel_mode
  scenario_type          = var.scenario_type
  provisioner            = var.provisioner
  background             = var.background
  monitoring_enabled     = var.monitoring_enabled
}

module "drbd_node" {
  source                 = "./modules/drbd_node"
  name                   = "drbd"
  source_image           = var.drbd_source_image
  volume_name            = var.drbd_source_image != "" ? "" : (var.drbd_volume_name != "" ? var.drbd_volume_name : local.generic_volume_name)
  drbd_count             = var.drbd_enabled == true ? var.drbd_count : 0
  vcpu                   = var.drbd_node_vcpu
  memory                 = var.drbd_node_memory
  bridge                 = "br0"
  host_ips               = local.drbd_ips
  drbd_cluster_vip       = local.drbd_cluster_vip
  drbd_disk_size         = var.drbd_disk_size
  shared_storage_type    = var.drbd_shared_storage_type
  iscsi_srv_ip           = module.iscsi_server.output_data.private_addresses.0
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  devel_mode             = var.devel_mode
  provisioner            = var.provisioner
  background             = var.background
  monitoring_enabled     = var.monitoring_enabled
  isolated_network_id    = local.internal_network_id
  isolated_network_name  = local.internal_network_name
  storage_pool           = var.storage_pool
  sbd_disk_id            = module.drbd_sbd_disk.id
}

module "monitoring" {
  source                 = "./modules/monitoring"
  name                   = "monitoring"
  monitoring_enabled     = var.monitoring_enabled
  source_image           = var.monitoring_source_image
  volume_name            = var.monitoring_source_image != "" ? "" : (var.monitoring_volume_name != "" ? var.monitoring_volume_name : local.generic_volume_name)
  vcpu                   = var.monitoring_vcpu
  memory                 = var.monitoring_memory
  bridge                 = "br0"
  storage_pool           = var.storage_pool
  isolated_network_id    = local.internal_network_id
  isolated_network_name  = local.internal_network_name
  monitoring_srv_ip      = local.monitoring_srv_ip
  reg_code               = var.reg_code
  reg_email              = var.reg_email
  reg_additional_modules = var.reg_additional_modules
  ha_sap_deployment_repo = var.ha_sap_deployment_repo
  provisioner            = var.provisioner
  background             = var.background
  hana_targets           = concat(local.hana_ips, [local.hana_cluster_vip]) # we use the vip to target the active hana instance
  drbd_targets           = var.drbd_enabled ? local.drbd_ips : []
  netweaver_targets      = var.netweaver_enabled ? local.netweaver_virtual_ips : []
}

module "netweaver_node" {
  source                     = "./modules/netweaver_node"
  name                       = "netweaver"
  source_image               = var.netweaver_source_image
  volume_name                = var.netweaver_source_image != "" ? "" : (var.netweaver_volume_name != "" ? var.netweaver_volume_name : local.generic_volume_name)
  netweaver_count            = var.netweaver_enabled == true ? 4 : 0
  vcpu                       = var.netweaver_node_vcpu
  memory                     = var.netweaver_node_memory
  bridge                     = "br0"
  storage_pool               = var.storage_pool
  isolated_network_id        = local.internal_network_id
  isolated_network_name      = local.internal_network_name
  host_ips                   = local.netweaver_ips
  virtual_host_ips           = local.netweaver_virtual_ips
  shared_disk_id             = module.netweaver_shared_disk.id
  hana_ip                    = local.hana_cluster_vip
  netweaver_product_id       = var.netweaver_product_id
  netweaver_inst_media       = var.netweaver_inst_media
  netweaver_swpm_folder      = var.netweaver_swpm_folder
  netweaver_sapcar_exe       = var.netweaver_sapcar_exe
  netweaver_swpm_sar         = var.netweaver_swpm_sar
  netweaver_swpm_extract_dir = var.netweaver_swpm_extract_dir
  netweaver_sapexe_folder    = var.netweaver_sapexe_folder
  netweaver_additional_dvds  = var.netweaver_additional_dvds
  netweaver_nfs_share        = var.drbd_enabled ? "${local.drbd_cluster_vip}:/HA1" : var.netweaver_nfs_share
  reg_code                   = var.reg_code
  reg_email                  = var.reg_email
  reg_additional_modules     = var.reg_additional_modules
  ha_sap_deployment_repo     = var.ha_sap_deployment_repo
  provisioner                = var.provisioner
  background                 = var.background
  monitoring_enabled         = var.monitoring_enabled
  devel_mode                 = var.devel_mode
}
