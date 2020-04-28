terraform {
  required_version = ">= 0.12"
}

resource "libvirt_volume" "monitoring_image_disk" {
  count            = var.monitoring_enabled == true ? 1 : 0
  name             = format("%s-monitoring-disk", terraform.workspace)
  source           = var.source_image
  base_volume_name = var.volume_name
  pool             = var.storage_pool
}

resource "libvirt_domain" "monitoring_domain" {
  name       = "${terraform.workspace}-${var.name}"
  count      = var.monitoring_enabled == true ? 1 : 0
  memory     = var.memory
  vcpu       = var.vcpu
  qemu_agent = true

  disk {
    volume_id = libvirt_volume.monitoring_image_disk.0.id
  }

  network_interface {
    wait_for_lease = true
    network_name   = var.network_name
    bridge         = var.bridge
    mac            = var.mac
  }

  network_interface {
    wait_for_lease = false
    network_name   = var.isolated_network_name
    network_id     = var.isolated_network_id
    hostname       = "${terraform.workspace}-${var.name}"
    addresses      = [var.monitoring_srv_ip]
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  cpu = {
    mode = "host-passthrough"
  }
}

output "output_data" {
  value = {
    id              = join("", libvirt_domain.monitoring_domain.*.id)
    hostname        = join("", libvirt_domain.monitoring_domain.*.name)
    private_address = var.monitoring_srv_ip
    address         = join("", libvirt_domain.monitoring_domain.*.network_interface.0.addresses.0)
  }
}

module "monitoring_on_destroy" {
  source       = "../../../generic_modules/on_destroy"
  node_count   = var.monitoring_enabled ? 1 : 0
  instance_ids = libvirt_domain.monitoring_domain.*.id
  user         = "root"
  password     = "linux"
  public_ips   = libvirt_domain.monitoring_domain.*.network_interface.0.addresses.0
  dependencies = [libvirt_domain.monitoring_domain]
}
