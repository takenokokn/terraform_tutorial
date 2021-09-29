## VARIABLES ########################################################################################################
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}

# Choose an Availability Domain
variable "AD" {
    default = "1"
}

variable "InstanceShape" {
    default = "VM.Standard1.1"
}

variable "InstanceImageOCID" {
    type = "map"
    default = {
        // Oracle-provided image "Oracle-Linux-7.4-2017.12.18-0"
        // See https://docs.us-phoenix-1.oraclecloud.com/Content/Resources/Assets/OracleProvidedImageOCIDs.pdf
        us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaasc56hnpnx7swoyd2fw5gyvbn3kcdmqc2guiiuvnztl2erth62xnq"
        us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaaxrqeombwty6jyqgk3fraczdd63bv66xgfsqka4ktr7c57awr3p5a"
        eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaayxmzu6n5hsntq4wlffpb4h6qh6z3uskpbm5v3v4egqlqvwicfbyq"
    }
}

variable "DBSize" {
    default = "50" // size in GBs
}

variable "BootStrapFile" {
    default = "./userdata/bootstrap"
}

#####################################################################################################################################
##User Data variable - instead of including an external file for the cloud init script, it can be defined here
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


## PROVIDER ########################################################################################################

provider "oci" {
  tenancy_ocid = "${var.tenancy_ocid}"
  user_ocid = "${var.user_ocid}"
  fingerprint = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region = "${var.region}"
  disable_auto_retries = "true"
}

## DATASOURCES #####################################################################################################

# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
    compartment_id = "${var.tenancy_ocid}"
}

## NETWORKING RESOURCES ############################################################################################
resource "oci_core_virtual_network" "ExampleVCN" {
  cidr_block = "10.1.0.0/16"
  compartment_id = "${var.compartment_ocid}"
  display_name = "TFExampleVCN"
  dns_label = "tfexamplevcn"
}

resource "oci_core_subnet" "ExampleSubnet" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  cidr_block = "10.1.20.0/24"
  display_name = "TFExampleSubnet"
  dns_label = "tfexamplesubnet"
  ## security_list_ids = ["${oci_core_virtual_network.ExampleVCN.default_security_list_id}"] ## Use Example SL instead of default.
  security_list_ids   = ["${oci_core_security_list.ExampleSL.id}"]

  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.ExampleVCN.id}"
  route_table_id = "${oci_core_route_table.ExampleRT.id}"
  dhcp_options_id = "${oci_core_virtual_network.ExampleVCN.default_dhcp_options_id}"
}

resource "oci_core_internet_gateway" "ExampleIG" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "TFExampleIG"
  vcn_id = "${oci_core_virtual_network.ExampleVCN.id}"
}

resource "oci_core_route_table" "ExampleRT" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.ExampleVCN.id}"
  display_name = "TFExampleRouteTable"
  route_rules {
    cidr_block = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.ExampleIG.id}"
  }
}

resource "oci_core_security_list" "ExampleSL" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "ExampleSL"
  vcn_id         = "${oci_core_virtual_network.ExampleVCN.id}"

  egress_security_rules = [{
    protocol    = "all"
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



## BLOCK RESOURCES ############################################################################################

resource "oci_core_volume" "TFBlock" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "TFBlock"
  size_in_gbs = "${var.DBSize}"
}

resource "oci_core_volume_attachment" "TFBlockAttach" {
    attachment_type = "iscsi"
    compartment_id = "${var.compartment_ocid}"
    instance_id = "${oci_core_instance.TFInstance.id}"
    volume_id = "${oci_core_volume.TFBlock.id}"
}



## COMPUTE RESOURCES ############################################################################################

resource "oci_core_instance" "TFInstance" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "TFInstance${count.index}"
  image = "${var.InstanceImageOCID[var.region]}"
  shape = "${var.InstanceShape}"
  subnet_id = "${oci_core_subnet.ExampleSubnet.id}"

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(var.user-data)}"
  }

  timeouts {
    create = "60m"
  }
}

 
## REMOTE EXEC PROVISIONER ############################################################################################

resource "null_resource" "remote-exec" {
    provisioner "remote-exec" {
      connection {
        agent = false
        timeout = "30m"
        host = "${oci_core_instance.TFInstance.public_ip}"
        user = "opc"
        private_key = "${var.ssh_private_key}"
    }
      inline = [
        "touch ~/IMadeAFile.Right.Here",
        "sudo iscsiadm -m node -o new -T ${oci_core_volume_attachment.TFBlockAttach.iqn} -p ${oci_core_volume_attachment.TFBlockAttach.ipv4}:${oci_core_volume_attachment.TFBlockAttach.port}",
        "sudo iscsiadm -m node -o update -T ${oci_core_volume_attachment.TFBlockAttach.iqn} -n node.startup -v automatic",
        "echo sudo iscsiadm -m node -T ${oci_core_volume_attachment.TFBlockAttach.iqn} -p ${oci_core_volume_attachment.TFBlockAttach.ipv4}:${oci_core_volume_attachment.TFBlockAttach.port} -l >> ~/.bashrc"
      ]
    }
}

## OUTPUTS ############################################################################################
# Output the private and public IPs of the instance
output "InstancePrivateIPs" {
value = ["${oci_core_instance.TFInstance.private_ip}"]
}

output "InstancePublicIPs" {
value = ["${oci_core_instance.TFInstance.public_ip}"]
}


