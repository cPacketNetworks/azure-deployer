#!/bin/bash


capture_nic_ip=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

cat >/home/cpacket/boot_config.toml <<EOF_BOOTCFG
{
"vm_type"               : "azure",
"cvuv_mode"             : "inline",
"cvuv_mirror_eth_0"     : "$capture_nic",

"cvuv_vxlan_srcip_0"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_0" : "",
"cvuv_vxlan_id_0"       : "1337",

"cvuv_vxlan_srcip_1"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_1" : "",
"cvuv_vxlan_id_1"       : "1338",

"cvuv_vxlan_srcip_2"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_2" : "",
"cvuv_vxlan_id_2"       : "1339",

"cvuv_vxlan_srcip_3"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_3" : "",
"cvuv_vxlan_id_3"       : "1340",

"cvuv_vxlan_srcip_4"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_4" : "",
"cvuv_vxlan_id_4"       : "1341",

"cvuv_vxlan_srcip_5"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_5" : "",
"cvuv_vxlan_id_5"       : "1342",

"cvuv_vxlan_srcip_6"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_6" : "",
"cvuv_vxlan_id_6"       : "1343",

"cvuv_vxlan_srcip_7"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_7" : "",
"cvuv_vxlan_id_7"       : "1344",

"cvuv_vxlan_srcip_8"    : "$capture_nic_ip",
"cvuv_vxlan_remoteip_8" : "",
"cvuv_vxlan_id_8"       : "1345",

}
EOF_BOOTCFG



IFS=' ' read -ra ADDR <<< "$REMOTE_IPS"
for i in "${!ADDR[@]}"; do
  # Set the remote IPs in the cvu_vxlan_remoteip_* variables
  sed -i "s|'cvuv_vxlan_remoteip_$i' : '',|'cvuv_vxlan_remoteip_$i' : '${ADDR[i]}',|" /home/cpacket/boot_config.toml
done

chmod ug+w /home/cpacket/boot_config.toml
echo "cloud-init ran user-data at: " $(date) >>/home/cpacket/prebootmsg.txt