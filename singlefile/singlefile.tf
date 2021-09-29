# source env-vars / env-vars.ps1 to set the authentication variables.
#
# This is simplified terraform template that consolidates everything to one file. 
# This will create a VCN, internet gateway, route table, security groups and start an instance. 
# Because the instance's image ocid is hardcoded it may need to be changed. There is a mechanism to request
# latest instance id's shown in a different sample file and in comments below. oci cli can also list out images 
# and their respective OCIDs
#
# Your ssh public key should be susbstituted for the sample one inline
#
# When the instance is up it should be ping-able and ssh-accessible via the opc user (ubuntu images use ubuntu rather than opc)
#

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "region" {}

## Latest Image OCIDs for each Region
variable "InstanceImageOCID" {
    type = "map"
    default = {
        // Oracle-provided image "Oracle-Linux-7.4-2018.01.20-0"
        // See https://docs.us-phoenix-1.oraclecloud.com/Content/Resources/Assets/OracleProvidedImageOCIDs.pdf
                    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaav4gjc4l232wx5g5drypbuiu375lemgdgnc7zg2wrdfmmtbtyrc5q"
                    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaautkmgjebjmwym5i6lvlpqfzlzagvg5szedggdrbp6rcjcso3e4kq"
        eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt1.aaaaaaaajdge4yzm5j7ci7ryzte7f3qgcekljjw7p6nexhnsvwt6hoybcu3q"
    }
}



provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region           = "${var.region}"
  disable_auto_retries = "true"
}

variable "VPC-CIDR" {
  default = "10.0.0.0/16"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

resource "oci_core_virtual_network" "CompleteVCN" {
  cidr_block     = "${var.VPC-CIDR}"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "CompleteVCN"
}

resource "oci_core_internet_gateway" "CompleteIG" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "CompleteIG"
  vcn_id         = "${oci_core_virtual_network.CompleteVCN.id}"
}

resource "oci_core_route_table" "RouteForComplete" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.CompleteVCN.id}"
  display_name   = "RouteTableForComplete"

  route_rules {
    cidr_block        = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.CompleteIG.id}"
  }
}

resource "oci_core_security_list" "SLSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "SLSubnet"
  vcn_id         = "${oci_core_virtual_network.CompleteVCN.id}"

  egress_security_rules = [{
    protocol    = "6"
    destination = "0.0.0.0/0"
  },
    {
      protocol    = "1"
      destination = "0.0.0.0/0"
    },
  ]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  },
    {
      icmp_options {
        "type" = 0
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 3
        "code" = 4
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 8
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
  ]
}

##User Data variable - instead including an external file for the cloud init script, it can be defined here
variable "user-data" {
  default = <<EOF
#!/bin/bash -x
echo '################### userdata begins #####################'
touch ~opc/userdata.`date +%s`.start

# echo '########## yum update ###############'
# yum update -y
touch ~opc/userdata.`date +%s`.finish
echo '################### userdata ends #######################'
EOF
}


## Get latest image list from provider, this pulls latest Oracle Linux 7.4
data "oci_core_images" "image-list" {
  compartment_id = "${var.compartment_ocid}"
  operating_system = "Oracle Linux"
  operating_system_version = "7.4"
}

resource "oci_core_subnet" "SNSubnetAD1" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  cidr_block          = "10.0.7.0/24"
  display_name        = "SNSubnetAD1"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_virtual_network.CompleteVCN.id}"
  route_table_id      = "${oci_core_route_table.RouteForComplete.id}"
  security_list_ids   = ["${oci_core_security_list.SLSubnet.id}"]
  dhcp_options_id     = "${oci_core_virtual_network.CompleteVCN.default_dhcp_options_id}"
}

resource "oci_core_instance" "SingleInstance1" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  # compartment_id      = "ocid1.compartment.oc1..aaaaaaaa3djcs6r45z6hri64tj5onmn6sbuoh4eeapshzabjjgedczz2qgra"
  display_name = "SingleInstance1"
  #image        = "ocid1.image.oc1.phx.aaaaaaaa6uwtn7h3hogd5zlwd35eeqbndurkayshzvrfx5usqn6cwxd5vdqq"
  image = "${var.InstanceImageOCID[var.region]}"

  metadata {
    #ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP+9AUhkNE0i8kpW0uCBYZ2hThAnvAYAW3ejeAuYVSokse7z7LdENFap+FKtestGgQhdLQTqr6KsJmIpHtxwk25Koy29rt431pgw0QWZTkmBaQ6v5Zs8OHJeWlaQyrKLiggCSS/vzEErafMyKd8OeaGY86KelUOfCwR3qzBUvyIPExzQqJUTdUwyPN/fFHe74tCZ967YVyMKB4BenoO7mhACmQ8hRNMcTk7p5BUaEN7S0WZjXhc5XK8Tk20oYx9PK7yu1xYeWgQCkRyZmyz5psyrAG0oh/PuGt5TxsuSgBJNycVaW6RBkOp62AWtlI3EVX35/F/Bkq3IXslvIKBh5b user@host"
    ssh_authorized_keys = "${var.ssh_public_key}"
    #user_data           = "IyEvYmluL2Jhc2gKdG91Y2ggL3Jvb3Qvc3RhcnRpbmdfcnVuCnl1bSB1cGRhdGUgLXkKdG91Y2ggL3Jvb3QvcnVuX2NvbXBsZXRlCg=="
    user_data = "${base64encode(var.user-data)}"
  }
  shape     = "VM.Standard1.2"
  subnet_id = "${oci_core_subnet.SNSubnetAD1.id}"
}


### Display Public IP of Instance
# Gets a list of vNIC attachments on the instance
data "oci_core_vnic_attachments" "SingleInstanceVnics" {
  compartment_id      = "${var.compartment_ocid}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  instance_id         = "${oci_core_instance.SingleInstance1.id}"
}

# Gets the OCID of the first (default) vNIC
data "oci_core_vnic" "SingleInstanceVnic" {
  vnic_id = "${lookup(data.oci_core_vnic_attachments.SingleInstanceVnics.vnic_attachments[0],"vnic_id")}"
}

output "InstancePublicIP" {
  value = ["${data.oci_core_vnic.SingleInstanceVnic.public_ip_address}"]
}

#######################################################
### Options when starting instances
#resource "oci_core_instance" "SingleInstance1" {
# availability_domain = "GOfA:PHX-AD-1"
### availability domain lookup method:
# availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
# compartment_id = "ocid1.compartment.oc1..aaaaaaaa3djcs6r45z6hri64tj5onmn6sbuoh4eeapshzabjjgedczz2qgra"
# compartment_id ; environment ; export TF_VAR_compartment_ocid=ocid1.compartment.oc1..aaaaaaaa3djcs6r45z6hri64tj5onmn6sbuoh4eeapshzabjjgedczz2qgra
# compartment_id = "${var.compartment_ocid}"
# display_name = "SingleInstance1"
# image = "ocid1.image.oc1.phx.aaaaaaaa6uwtn7h3hogd5zlwd35eeqbndurkayshzvrfx5usqn6cwxd5vdqq" 
### imaage - lookup method: 
# image = "${lookup(data.oci_core_images.OLImageOCID.images[0], "id")}"
# data "oci_core_images" "OLImageOCID" {
# operating_system         = "Oracle Linux"
# operating_system_version = "7.3" }
#  
### Metadata - typically supply the SSH key(s) and a encoded string or a base64encode of a file for the startup script. 
# metadata {
#   ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP+9AUhkNE0i8kpW0uCBYZ2hThAnvAYAW3ejeAuYVSokse7z7LdENFap+FKtestGgQhdLQTqr6KsJmIpHtxwk25Koy29rt431pgw0QWZTkmBaQ6v5Zs8OHJeWlaQyrKLiggCSS/vzEErafMyKd8OeaGY86KelUOfCwR3qzBUvyIPExzQqJUTdUwyPN/fFHe74tCZ967YVyMKB4BenoO7mhACmQ8hRNMcTk7p5BUaEN7S0WZjXhc5XK8Tk20oYx9PK7yu1xYeWgQCkRyZmyz5psyrAG0oh/PuGt5TxsuSgBJNycVaW6RBkOp62AWtlI3EVX35/F/Bkq3IXslvIKBh5b user@host"
#    user_data           = "${base64encode(file(var.InstanceBootStrap))}"
#}
#  metadata.% = "2"
#  metadata.ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP+9AUhkNE0i8kpW0uCBYZ2hThAnvAYAW3ejeAuYVSokse7z7LdENFap+FKtestGgQhdLQTqr6KsJmIpHtxwk25Koy29rt431pgw0QWZTkmBaQ6v5Zs8OHJeWlaQyrKLiggCSS/vzEErafMyKd8OeaGY86KelUOfCwR3qzBUvyIPExzQqJUTdUwyPN/fFHe74tCZ967YVyMKB4BenoO7mhACmQ8hRNMcTk7p5BUaEN7S0WZjXhc5XK8Tk20oYx9PK7yu1xYeWgQCkRyZmyz5psyrAG0oh/PuGt5TxsuSgBJNycVaW6RBkOp62AWtlI3EVX35/F/Bkq3IXslvIKBh5b user@host"
#  metadata.user_data = IyEvYmluL2Jhc2gKdG91Y2ggL3Jvb3Qvc3RhcnRpbmdfcnVuCnl1bSB1cGRhdGUgLXkKdG91Y2ggL3Jvb3QvcnVuX2NvbXBsZXRlCg== 
#   shape = "VM.Standard1.2"
#   subnet_id = "${oci_core_subnet.SNSubnetAD1.id}"  
#
#}
#
### Image list
## Gets the OCID of the OS image to use
#data "oci_core_images" "OLImageOCID" {
#  compartment_id           = "${var.compartment_ocid}"
#  operating_system         = "${var.InstanceOS}"
#  operating_system_version = "${var.InstanceOSVersion}"
#}
#  image               = "${lookup(data.oci_core_images.OLImageOCID.images[0], "id")}"
#
### oci cli sample image list command
# oci compute image list -c ocid1.compartment.oc1..aaaaaaaa3djcs6r45z6hri64tj5onmn6sbuoh4eeapshzabjjgedczz2qgra
