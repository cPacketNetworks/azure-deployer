#!/usr/bin/env bash

# cVu-V-k inline mode config example

# cvuv_nat_xxx values define NAT passthroughs - up to 4 allowed
#   (suffix _0,_1,_2, _3)
#    NOTE : local RESERVED ports 443,80,22,161,162
# cvuv_nat_loc_ip, cvuv_nat_dst_ip : emptry strings ('') will disable that nat port

# for cvuv_vxlan_srcip, cvuv_vxlan_remoteip : empty strings ('') will disable
# the vxlan output port.

# cVu-V-k inline
touch /home/cpacket/boot_config.toml
chmod a+w /home/cpacket/boot_config.toml

cat >/home/cpacket/boot_config.toml <<EOF_BOOTCFG
{
'vm_type'               : 'azure',
'capture_mode'          : 'cvuv',
'cvuv_mode'             : 'inline',
'cvuv_inline_mode'      : 'tctap',
'cvuv_mirror_eth_0'     : 'eth0',

'cvuv_vxlan_srcip_0'    : '',
'cvuv_vxlan_remoteip_0' : '',
'cvuv_vxlan_id_0'       : '1337',

'cvuv_vxlan_srcip_1'    : '',
'cvuv_vxlan_remoteip_1' : '',
'cvuv_vxlan_id_1'       : '1338',

'cvuv_vxlan_srcip_2'    : '',
'cvuv_vxlan_remoteip_2' : '',
'cvuv_vxlan_id_2'       : '1339',

}
EOF_BOOTCFG

echo "cloud-init ran user-data at: " $(date) >>/home/cpacket/prebootmsg.txt
