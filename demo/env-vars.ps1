### Substitute USERNAME-Lab to correct the path if not using Lab
### Substitute the OCIDs, fingerprints and keys with the correct ones for your environment
### Authentication details
$env:TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..aaaaaaaagz5mmtj5udlmlis53djmfjr2d5qy6muf3gau4a6jkeyaztat7c5a"
$env:TF_VAR_user_ocid="ocid1.user.oc1..aaaaaaaate2kvvnyhel67ujductkiq6arlxm5vbk4vxmgo2isuo2mgqwooiq"
$env:TF_VAR_fingerprint="34:61:ea:b5:7d:06:68:49:ef:76:48:bf:d7:60:cc:57"
$env:TF_VAR_private_key_path="C:\Users\Lab\.oci\oci_api_key.pem"

### Compartment
$env:TF_VAR_compartment_ocid="ocid1.compartment.oc1..aaaaaaaanbmgn3tejodjdtx54m4v6i4nyjzyiugvphwhzrrpnk7qhwa3746a"

### Public/private keys used on the instances
$env:TF_VAR_ssh_public_key = Get-Content C:\Users\Lab\.ssh\id_rsa.pub -Raw
$env:TF_VAR_ssh_private_key = Get-Content C:\Users\Lab\.ssh\id_rsa -Raw

### Region
$env:TF_VAR_region="us-phoenix-1"

### Check variables are set in PowerShell wth "dir env:"
#
#
