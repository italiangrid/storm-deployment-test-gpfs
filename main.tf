# Input variables
variable "vm_fip" {
  type = "string"
  default = "131.154.96.127"
}

variable "mw_username" {
  type = "string"
  default = "mw-user"
}

variable "mw_password" {
  type = "string"
  default = "password"
}

variable "mw_tenant" {
  type = "string"
  default = "MW-DEVEL"
}

variable "vm_image" {
  type = "string"
  default = "centos-6-1804-x86_64-generic-gpfs-client-certs"
}

variable "vm_name" {
  type = "string"
  default = "cloud-vm127"
}

variable "vm_flavor" {
  type = "string"
  default = "m1.medium"
}

variable "vm_network_name" {
  type = "string"
  default = "net-mw-devel"
}

variable "vm_network_ipv4" {
  type = "string"
  default = "10.50.9.114"
}

variable "ssh_key_file" {
  type = "string"
  default = "/home/jenkins/.ssh/id_rsa"
}

# Provider settings
provider "openstack" {
  user_name = "${var.mw_username}"
  tenant_name = "${var.mw_tenant}"
  password = "${var.mw_password}"
  auth_url = "https://horizon.cloud.cnaf.infn.it:5000/v3"
  region = "regionOne"
  domain_name = "Default"
}

resource "openstack_compute_instance_v2" "test" {
  name = "${var.vm_name}"
  image_name = "${var.vm_image}"
  flavor_name = "${var.vm_flavor}"
  key_pair = "jenkins"
  security_groups = ["default", "storm"]

  network {
    name = "${var.vm_network_name}"
    fixed_ip_v4 = "${var.vm_network_ipv4}"
  }
}

# Assign floating ip
resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${var.vm_fip}"
  instance_id = "${openstack_compute_instance_v2.test.id}"
}

# Upload configuration scripts
resource "null_resource" "configure" {
  connection {
    type = "ssh"
        user = "centos"
        agent = false
        private_key = "${file("${var.ssh_key_file}")}"
        host = "${var.vm_fip}"
  }

  provisioner "file" {
        source = "conf/"
        destination = "/home/centos"
  }

  depends_on = [
    "openstack_compute_floatingip_associate_v2.fip_1",
  ]
}

# Boostrap as GPFS cluster client
resource "null_resource" "bootstrap-gpfs" {
  connection {
    type = "ssh"
        user = "centos"
        agent = false
        private_key = "${file("${var.ssh_key_file}")}"
        host = "${var.vm_fip}"
  }

  provisioner "remote-exec" {
        inline = "sudo sh bootstrap-gpfs.sh"
  }

  depends_on = [
    "null_resource.configure",
  ]
}

# Provision script: run puppet and install useful stuff
resource "null_resource" "provision" {
  connection {
    type = "ssh"
        user = "centos"
        agent = false
        private_key = "${file("${var.ssh_key_file}")}"
        host = "${var.vm_fip}"
  }

  provisioner "remote-exec" {
        inline = "sudo sh provision.sh"
  }

  depends_on = [
    "null_resource.bootstrap-gpfs",
  ]
}

# Deploy StoRM
resource "null_resource" "deploy" {
  connection {
    type = "ssh"
        user = "centos"
        agent = false
        private_key = "${file("${var.ssh_key_file}")}"
        host = "${var.vm_fip}"
  }

  provisioner "remote-exec" {
        inline = "sudo sh deploy.sh"
  }

  depends_on = [
    "null_resource.provision",
  ]
}
