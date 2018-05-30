# Provider settings
provider "openstack" {
  user_name = "${MW_DEVEL_USERNAME}"
  tenant_name = "MW-DEVEL"
  password = "${MW_DEVEL_PASSWORD}"
  auth_url = "https://horizon.cloud.cnaf.infn.it:5000/v3"
  region = "regionOne"
  domain_name = "Default"
}

resource "openstack_compute_instance_v2" "test" {
  name = "${VM_NAME}"
  image_name = "${IMAGE_NAME}"
  flavor_name = "${FLAVOR_NAME}"
  key_pair = "jenkins"
  security_groups = ["default"]

  network {
    name = "net-mw-devel"
    fixed_ip_v4 = "${FIXED_IPV4}"
  }
}

# Assign floating ip
resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${FIP_ADDRESS}"
  instance_id = "${openstack_compute_instance_v2.test.id}"
}

# Upload configuration scripts
resource "null_resource" "configure" {
  connection {
    type = "ssh"
  	user = "centos"
  	agent = false
  	private_key = "${JENKINS_SSH_KEY_FILE}"
  	host = "${FIP_ADDRESS}"
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
        private_key = "${JENKINS_SSH_KEY_FILE}"
        host = "${FIP_ADDRESS}"
  }
  
  provisioner "remote-exec" {
        inline = "sudo sh bootstrap-gpfs.sh"
  }

  depends_on = [
    "null_resource.configure",
  ]
}
