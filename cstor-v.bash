#!/bin/bash

chmod ug+w /home/cpacket/boot_config.txt

# cstor-V inline boot config settings
cat <<EOF_BOOTCFG >/home/cpacket/boot_config.txt
{
'capture_nic_index': 1,
'eth_dev' : 'eth1',
'run_cflow_mode': True
}
EOF_BOOTCFG