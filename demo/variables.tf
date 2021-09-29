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
    default = "VM.Standard1.2"
}

variable "InstanceImageOCID" {
    type = map(string)
    default = {
        // Oracle-provided image "Oracle-Linux-7.4-2018.01.20-0"
        // See https://docs.us-phoenix-1.oraclecloud.com/Content/Resources/Assets/OracleProvidedImageOCIDs.pdf
                    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaav4gjc4l232wx5g5drypbuiu375lemgdgnc7zg2wrdfmmtbtyrc5q"
                    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaautkmgjebjmwym5i6lvlpqfzlzagvg5szedggdrbp6rcjcso3e4kq"
        eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt1.aaaaaaaajdge4yzm5j7ci7ryzte7f3qgcekljjw7p6nexhnsvwt6hoybcu3q"
    }
}

variable "DBSize" {
    default = "50" // size in GBs
}

variable "BootStrapFile" {
    default = "./userdata/bootstrap"
}
