#!/bin/bash

chmod ug+w /home/cpacket/boot_config.txt

# cstor-V inline boot config settings
cat <<EOF_BOOTCFG >/home/cpacket/boot_config.txt
{
'vm_mode': 'microsoft',
'capture_mode': 'libpcap',
'decap_mode': 'vxlan',
'num_pcap_bufs': 16,
'capture_nic_index': 1,
'pci_whitelist': '0001:00:02.0',
'eth_dev' : 'eth1',
'core_mask': '0x3',
'burnside_mode': False,
'cstor_lite_mode': False,
'ssh': {'enabled': True},
'cleanup_threshold' : 30,
'use_compression' : True,
'tiered_stor_en': False,
'run_cflow_mode': True
}
EOF_BOOTCFG