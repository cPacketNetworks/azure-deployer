#!/bin/bash

# exit on non-zero status to any command
set -e 

function get_filename {
    # remove the SAS
    url=${1%\?*}
    # remove to last /
    echo "${url##*/}"
}

function get_account_name {
    # remove the SAS
    url=${1%\?*}
    front=${url%%\.*}
    echo "${front##*/}"
}

function get_container_name {
    # remove the SAS
    url=${1%\?*}
    tmp=${url%/*}
    echo ${tmp##*/}
}

function get_tld {
    url=${1#*.}
    echo "${url%%/*}"
}

cpacket_uri_file="./cpacket_uri.txt"
my_container_name="tmpcpacketvhds"
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
read -ep "Enter your existing storage account name: " -i "$my_account_name" my_account_name
my_resource_group=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .resourceGroup | tr -d '"')
my_image_rg="$my_resource_group"
my_image_loc=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .location | tr -d '"')
my_blob_url=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .primaryEndpoints.blob | tr -d '"')
storage_base_name=$(get_tld "$my_blob_url")

container_is_created=$(az storage container exists --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name)
if [ $container_is_created == "True" ]; then
    echo "Removing previous temp directory"
    previous_container_deleted=$(az storage container delete --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name)
fi

if [ $uri_prompt -eq 1 ]; then
     echo ""
     echo "The following infomation is what you recived from cPacket Networks."
     read -ep "Enter the CCLEAR-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CCLEAR-V URI: " -i "$cclear_uri" cclear_uri
     read -ep "Enter the CSTOR-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CSTOR-V URI: " -i "$cstor_uri" cstor_uri
     read -ep "Enter the CVU-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CVU-V URI: " -i "$cvu_uri" cvu_uri
fi

echo "creating temporary storage container"
container_create=$(az storage container create --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name --resource-group $my_resource_group)

echo "creating 24 hour expiry date"
my_sas_expiry=$(date --date="+24 hours" +"%Y-%m-%dT%H:%M:%SZ")

echo "generating sas" 
my_sas_token=$(az storage container generate-sas --only-show-errors --account-name "$my_account_name" --name "$my_container_name" --permissions acw --expiry "$my_sas_expiry" | tr -d '"')

my_container_url="https://$my_account_name.$storage_base_name/$my_container_name?$my_sas_token"

if [ ! -z "$cclear_uri" ]; then
    echo "copying cclear vhd"
    copy --put-md5 "$cclear_uri" "$my_container_url"
    cclearimagename=$(get_filename "$cclear_uri")
    echo "creating cclear image"
    az image create --resource-group "$my_image_rg" --location "$my_image_loc" --name "$cclearimagename" --os-type Linux --source "https://$my_account_name.$storage_base_name/$my_container_name/$cclearimagename"
fi

if [ ! -z "$cstor_uri" ]; then
    echo "copying cstor vhd"
    azcopy copy --put-md5 "$cstor_uri" "$my_container_url"
    cvuimagename=$(get_filename "$cstor_uri")
    echo "creating cstor image"
    az image create --resource-group $my_image_rg --location $my_image_loc --name $cvuimagename --os-type Linux --source "https://$my_account_name.$storage_base_name/$my_container_name/$cvuimagename"
fi

if [ ! -z "$cvu_uri" ]; then
    echo "copying cvu vhd"
    azcopy copy --put-md5 "$cvu_uri" "$my_container_url"
    cstorimagename=$(get_filename "$cvu_uri")
    echo "creating cvu image"
    az image create --resource-group $my_image_rg --location $my_image_loc --name $cstorimagename --os-type Linux --source "https://$my_account_name.$storage_base_name/$my_container_name/$cstorimagename"
fi

container_deleted=$(az storage container delete --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name)
echo ""
echo "temporary container removed: $container_deleted"

az image list --output table --only-show-errors --resource-group $my_image_rg
