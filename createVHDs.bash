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
        echo "Copying $1 to $vhd_dest_url?$my_sas_token"
        azcopy copy "$1" "$vhd_dest_url?$my_sas_token"
        echo "Creating image $imagename"
        az image create --resource-group "$my_image_rg" --location "$my_image_loc" --name "$imagename" --os-type Linux --source "$vhd_dest_url"
    fi
}

cpacket_uri_file=${1:-'./cpacket_uri.txt'}
my_container_name="cpacketvhdstemp"
uri_prompt=1

if [ -r $cpacket_uri_file ]; then
    source $cpacket_uri_file
    echo "Loading settings from $cpacket_uri_file"
    uri_prompt=0
fi

echo "------------------------------------------------------------------------------------------------------------------------"
echo "This script will create a temporary container in an existing publicly accessable storage account to transfer VHD images."
echo "The temporary VHDs will be used to create deployable images for cPacket cCloud."
echo "------------------------------------------------------------------------------------------------------------------------"

if [ $uri_prompt -eq 1 ]; then
    read -ep "Enter your existing storage account name: " -i "$my_account_name" my_account_name
fi

echo -n "Checking if $my_account_name storage account is publicly accessable..."
storage_account_publicnetworkaccess=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .publicNetworkAccess | tr -d '"')
storage_account_publicnetworkaccessdefaultrule=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .networkRuleSet.defaultAction | tr -d '"')
if [ $storage_account_publicnetworkaccess == "Enabled" ] && [ $storage_account_publicnetworkaccessdefaultrule == "Allow" ]; then
    echo "Pass"
else
    echo "Fail"
    echo "To make this storage account publicly accessable,"
    echo "  Go to the Azure portal under the storage account $my_account_name -> Networking -> Firewalls and virtual networks -> Public network access -> Enabled from all networks"
    exit 1
fi

my_resource_group=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .resourceGroup | tr -d '"')
my_image_rg="$my_resource_group"
echo "Using Resource Group: $my_image_rg"
my_image_loc=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .location | tr -d '"')
echo "Using Location: $my_image_loc"
my_blob_url=$(az storage account show --output json --only-show-errors --name $my_account_name | jq .primaryEndpoints.blob | tr -d '"')
storage_base_name=$(get_tld "$my_blob_url")
echo "Storage Cloud: $storage_base_name"

if container_is_created
then 
    echo "-------------------------------------------------------------------------------------------------------------------------- "
    echo "Temporary Container $my_container_name is already created. This is a re-run."  
    echo "If the images fail to deploy or the script fails, manually remove $my_container_name from storage account $my_account_name."
    echo "---------------------------------------------------------------------------------------------------------------------------"
else 
    echo -n "Creating temporary storage container $my_container_name from $my_account_name..."
    container_create=$(az storage container create --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name --resource-group $my_resource_group)
    until container_is_created; do
        echo -n "."
        sleep 1
    done
    echo "Done"
fi

if [ $uri_prompt -eq 1 ]; then
     echo "The following infomation is what you recived from cPacket Networks."
     read -ep "Enter the CCLEAR-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CCLEAR-V URI: " -i "$cclear_uri" cclear_uri
     read -ep "Enter the CSTOR-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CSTOR-V URI: " -i "$cstor_uri" cstor_uri
     read -ep "Enter the CVU-V URI you recieved from cPacket Networks. Leave blank if you didn't get a CVU-V URI: " -i "$cvu_uri" cvu_uri
fi

echo "Creating 24 hour expiry date"
my_sas_expiry=$(date --date="+24 hours" +"%Y-%m-%dT%H:%M:%SZ")

echo -n "Generating sas..." 
my_sas_token=$(az storage container generate-sas --only-show-errors --account-name "$my_account_name" --name "$my_container_name" --permissions racwdl --expiry "$my_sas_expiry" | tr -d '"')
# check length is reasonable for output
if [ ${#my_sas_token} -gt 5 ]; then
    echo "Done"
else
    echo "Failed too short"
    echo "ERROR returned sas: $my_sas_token"
    exit 1
fi

copy_create_image "$cclear_uri"
copy_create_image "$cstor_uri"
copy_create_image "$cvu_uri"

echo -n "Removing temporary storage container $my_container_name from $my_account_name..."
container_deleted=$(az storage container delete --output tsv --only-show-errors --account-name $my_account_name --name $my_container_name)
# verify container gets deleted (== 0)
until container_is_created; [ "$?" -eq 1 ]; do
    echo -n "."
    sleep 1
done
echo "Done"

az image list --output table --only-show-errors --resource-group $my_image_rg
