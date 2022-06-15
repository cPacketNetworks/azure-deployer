#!/bin/bash

# exit on non-zero status to any command
set -e 

function get_filename {
    # remove the SAS
    local url=${1%\?*}
    # remove to last /
    echo "${url##*/}"
}

function get_account_name {
    # remove the SAS
    local url=${1%\?*}
    local front=${url%%\.*}
    echo "${front##*/}"
}

function get_container_name {
    # remove the SAS
    local url=${1%\?*}
    local tmp=${url%/*}
    echo ${tmp##*/}
}

function get_tld {
    local url=${1#*.}
    echo "${url%%/*}"
}

function container_is_created {
    local container_created=$(az storage container exists --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name)
    if [ $container_created == "True" ]
    then
        return 0
    else
        return 1
    fi
}

function copy_create_image {
    if [ ! -z "$1" ]; then
        local imagename=$(get_filename "$1")
        local vhd_dest_url="https://$my_account_name.$storage_base_name/$my_container_name/$imagename"
        echo "copying $imagename"
        azcopy copy "$1" "$vhd_dest_url?$my_sas_token"
        echo "creating image $imagename"
        az image create --resource-group "$my_image_rg" --location "$my_image_loc" --name "$imagename" --os-type Linux --source "$vhd_dest_url"
    fi
}

cpacket_uri_file=${1:-'./cpacket_uri.txt'}
my_container_name="cpacketvhdstemp"
uri_prompt=1

if [ -r $cpacket_uri_file ]; then
    source $cpacket_uri_file
    echo "loading $cpacket_uri_file"
    uri_prompt=0
fi

echo "This script will create image files for cPacket Azure cloud images."
echo "The script will create a temporary container in an existing storage account.  You MUST have a resource group and associated storage account already created."
echo "This storage account MUST be publicly accessable. In the portal under the storage account: Networking -> Firewalls and virtual networks -> All networks."

echo "" 
if [ $uri_prompt -eq 1 ]; then
    read -ep "Enter your existing storage account name: " -i "$my_account_name" my_account_name
fi
my_resource_group=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .resourceGroup | tr -d '"')
my_image_rg="$my_resource_group"
my_image_loc=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .location | tr -d '"')
my_blob_url=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .primaryEndpoints.blob | tr -d '"')
storage_base_name=$(get_tld "$my_blob_url")

echo -n "creating temporary storage container $my_container_name..."
until container_is_created; do
    echo -n "."
    container_create=$(az storage container create --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name --resource-group $my_resource_group)
    sleep 1
done
echo "Done"

if [ $uri_prompt -eq 1 ]; then
     echo ""
     echo "The following infomation is what you recived from cPacket Networks."
     read -ep "Enter the CCLEAR-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CCLEAR-V URI: " -i "$cclear_uri" cclear_uri
     read -ep "Enter the CSTOR-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CSTOR-V URI: " -i "$cstor_uri" cstor_uri
     read -ep "Enter the CVU-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CVU-V URI: " -i "$cvu_uri" cvu_uri
fi

echo "creating 24 hour expiry date"
my_sas_expiry=$(date --date="+24 hours" +"%Y-%m-%dT%H:%M:%SZ")

echo "generating sas" 
my_sas_token=$(az storage container generate-sas --only-show-errors --account-name "$my_account_name" --name "$my_container_name" --permissions acw --expiry "$my_sas_expiry" | tr -d '"')

copy_create_image "$cclear_uri"
copy_create_image "$cstor_uri"
copy_create_image "$cvu_uri"

echo -n "Removing temporary storage container $my_container_name..."
until container_is_created; [ "$?" -eq 1 ]; do
    echo -n "."
    container_deleted=$(az storage container delete --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name)
    sleep 1
done
echo "Done"

echo ""

az image list --output table --only-show-errors --resource-group $my_image_rg
