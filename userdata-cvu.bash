#!/bin/bash

# cVu-V-k inline mode config example

# cvuv_nat_xxx values define NAT passthroughs - up to 4 allowed
#   (suffix _0,_1,_2, _3)
#    NOTE : local RESERVED ports 443,80,22,161,162
# cvuv_nat_loc_ip, cvuv_nat_dst_ip : emptry strings ('') will disable that nat port

# for cvuv_vxlan_srcip, cvuv_vxlan_remoteip : empty strings ('') will disable
# the vxlan output port.

# cVu-V-k inline
cat <<EOF_BOOTCFG >/home/cpacket/boot_config.txt
{
'capture_mode'          : 'cvuv',
'cvuv_mode'             : 'inline',
'cvuv_inline_mode'      : 'tctap',
'cvuv_mirror_eth_0'     : 'eth1',
'cvuv_max_vxlan_ports'  : 3,

'cvuv_vxlan_dev_0'      : 'vxlan0',
'cvuv_vxlan_srcip_0'    : '',
'cvuv_vxlan_remoteip_0' : '',
'cvuv_vxlan_id_0'       : '2110',
'cvuv_vxlan_eth_0'      : 'cvuv_mirror_eth_0',

'cvuv_vxlan_dev_1'      : 'vxlan1',
'cvuv_vxlan_srcip_1'    : '',
'cvuv_vxlan_remoteip_1' : '',
'cvuv_vxlan_id_1'       : '2211',
'cvuv_vxlan_eth_1'      : 'cvuv_mirror_eth_0',

'cvuv_vxlan_dev_2'      : 'vxlan2',
'cvuv_vxlan_srcip_2'    : '',
'cvuv_vxlan_remoteip_2' : '',
'cvuv_vxlan_id_2'       : '2212',
'cvuv_vxlan_eth_2'      : 'cvuv_mirror_eth_0',

'cvuv_nat_loc_proto_0'  : 'tcp',
'cvuv_nat_loc_ip_0'     : '',
'cvuv_nat_loc_port_0'   : '',
'cvuv_nat_dst_ip_0'     : '',
'cvuv_nat_dst_port_0'   : '',

'burnside_mode'         : False,
'cstor_lite_mode'       : False,
'ssh'                   : {'enabled': True},
'capture_nic_eth' 	    : 'eth1',
'management_nic_eth'	: 'eth0',
}
EOF_BOOTCFG

# make writable so that next boot can overwrite if need be
chmod ug+w /home/cpacket/boot_config.txt

echo "cloud-init ran user-data at: " $(date) >>/home/cpacket/prebootmsg.txt