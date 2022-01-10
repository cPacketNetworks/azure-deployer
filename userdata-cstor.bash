#!/bin/bash

# cVu-V-k inline boot config settings
cat <<EOF_BOOTCFG >/home/cpacket/boot_config.txt
{
'vm_type': 'azure',
'capture_mode': 'libpcap',
'decap_mode': 'vxlan',
'num_pcap_bufs': 2,
'capture_nic_index': 0,
'pci_whitelist': '0001:00:02.0',
'eth_dev': 'eth0',
'core_mask': '0x3',
'burnside_mode': False,
'cstor_lite_mode': False,
'ssh': {'enabled': True},
'cleanup_threshold': 50,
'use_compression': False,
'tiered_stor_en': False,
'capture_nic_eth': 'eth0',
'management_nic_eth': 'eth0',
}
EOF_BOOTCFG

chmod ug+w /home/cpacket/boot_config.txt

echo "cloud-init ran user-data at: " $(date) >>/home/cpacket/prebootmsg.txt