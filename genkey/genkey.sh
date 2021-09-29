#!/bin/bash -x 

echo "This script will create API keys for use with OCI in ~/.oci"
read -p "If there is already API keys present on the system then ctrl+c - otherwise press [Enter]"



mkdir -p ~/.oci 
cd ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 0700 ~/.oci
chmod 0600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
cat ~/.oci/oci_api_key_public.pem
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem 2>/dev/null | openssl md5 -c
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem 2>/dev/null | openssl md5 -c > ~/.oci/oci_api_key_fingerprint

