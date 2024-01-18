#!/bin/bash
set -ex

config_file="/etc/cstor/boot-config.toml"

cat >"$config_file" <<EOF_BOOTCFG
[services.capture.sniffer.pcap]
interfaces = [ "eth0" ]
EOF_BOOTCFG

chmod a+w "$config_file"

echo "boot configuration: completed"

echo "cloud-init ran user-data at: " $(date) >>/home/ubuntu/prebootmsg.txt
