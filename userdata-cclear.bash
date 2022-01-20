#!/bin/bash
mkdir -p /opt/cloud/
cat <<EOF_DEPLOYER >/opt/cloud/deployer.py
#!/usr/bin/env python3

from os import environ
import ipaddress
import json
import requests
from requests.auth import HTTPBasicAuth
import urllib3
from urllib.parse import urlencode
from getpass import getpass

urllib3.disable_warnings()

debug = False
debug_mode = False

def set_debug_env(debug_dict):
    for i in debug_dict:
        if debug: print(i)
        environ[i['key']] = i['value']


def get_user(prompt):
    while True:
        try: 
            value = input(prompt)
        except ValueError:
            print("Not a valid entry")
            continue
        if len(value) < 1:
            print("Not enough characters")
            continue
        else: 
            break
    return value


def get_passwd(prompt):
    while True:
        try: 
            value = getpass(prompt)
        except ValueError:
            print("Not a valid entry")
            continue
        if len(value) < 1:
            print("Not enough characters")
            continue
        else: 
            break
    return value


def get_valid_ip(prompt):
    while True:
        try:
            value = input(prompt)
            value = '' if len(value) < 1 else ipaddress.ip_address(value)
        except ValueError:
            print("This is not a valid IP address")
            continue
        else:
            break
    return str(value)


def get_valid_ips(prompt):
    while True:
        try:
            value = input(prompt).split()
            is_valid_ip = all(ipaddress.ip_address(ip) for ip in value)
        except ValueError:
            print("The list caused an error, does the list contain an invalid IP address?")
            continue
        if not is_valid_ip:
            print("The list contains an invalid IP address")
            continue
        else:
            break
    return value


def get_valid_json(prompt):
    while True:
        try:
            value = json.loads(input(prompt))
        except ValueError:
            print("This is not correctly formated, please check this is valid json.")
            continue
        else:
            break
    return value


def get_requests(url):
    try:
        s = requests.get(url, auth=HTTPBasicAuth(user, password), verify=False)
    except requests.exceptions.RequestException as e:
        raise SystemExit(e)
    if 200 <= s.status_code <= 229:
        return s.json()
    else:
        return None


def post_request(url, post_payload):
    post_headers = {'Content-Type': 'application/json'}
    try:
        s = requests.post(url, auth=HTTPBasicAuth(user, password), verify=False, headers=post_headers, json=post_payload)
    except requests.exceptions.RequestException as e:
        raise SystemExit(e)
    if debug: print("{}  {}  {}".format(url, post_payload, s))
    return s

def get_system_settings(provisioning):
    # the structure of the provisioning input is assumed to be a dictionary like this:
    # [{"index":0,"name":"cstor-0","nic_name":"cstor-0-capture-nic","private_ip":"10.101.2.4"}]

    curss = dict()
    for key in provisioning:
        print("getting systems settings on {}".format(key['name']))
        ss = get_requests("https://{}/sys/10/getSystemSettings".format(key['private_ip']))
        if ss is not None:
            curss[key['name']] = ss
    return curss


def set_system_settings(t_settings, provisioning):
    # the structure of the target settings (t_setttings) is assumed to be a dictionary of system settings like this:
    #{ "cvu-0": {
    #    "cvuv_max_vxlan_ports": 3,
    #    "cvuv_vxlan_dev_0": "vxlan0"
    #    }
    #}

    curss = dict()
    for key in provisioning:
        print("setting the following systems settings on {}".format(key['name']))
        print(json.dumps(t_settings[key['name']], sort_keys=False, indent=4))
        ss = get_requests("https://{}/sys/10/updateASingleSystemSetting?{}".format(key['private_ip'], urlencode(t_settings[key['name']])))
        if ss is not None:
            curss[key['name']] = ss


def create_cvu_provisioining_settings():
    t_cvu_ss = dict()
    for cvukey in cvu_provisioning:
        settings = None
        i = 0
        vxlan_id_start = 200
        settings = dict(cvuv_max_vxlan_ports=num_cstors + num_tools)
        settings['stats_db_server'] = cclear_ip
        for cstorkey in cstor_provisioning:
            settings['cvuv_vxlan_dev_{}'.format(i)] = 'vxlan{}'.format(i)
            settings['cvuv_vxlan_srcip_{}'.format(i)] = cvukey['private_ip']
            settings['cvuv_vxlan_remoteip_{}'.format(i)] = cstorkey['private_ip']
            settings['cvuv_vxlan_id_{}'.format(i)] = vxlan_id_start + i
            # only supports single interface deployment 
            settings['cvuv_vxlan_eth_{}'.format(i)] = 'cvuv_mirror_eth_0'
            i = i + 1
        for ip in cvu_tool_ip:
            settings['cvuv_vxlan_dev_{}'.format(i)] = 'vxlan{}'.format(i)
            settings['cvuv_vxlan_srcip_{}'.format(i)] = cvukey['private_ip']
            settings['cvuv_vxlan_remoteip_{}'.format(i)] = ip
            settings['cvuv_vxlan_id_{}'.format(i)] = vxlan_id_start + i
            # only supports single interface deployment 
            settings['cvuv_vxlan_eth_{}'.format(i)] = 'cvuv_mirror_eth_0'
            i = i + 1
        t_cvu_ss[cvukey['name']] = settings
    if debug: print(json.dumps(t_cvu_ss, sort_keys=False, indent=4))
    return t_cvu_ss


def create_cstor_provisioning_settings():
    t_cstor_ss = dict()
    for cstorkey in cstor_provisioning:
        settings = None
        i = 0
        settings = dict()
        settings['stats_db_server'] = cclear_ip
        t_cstor_ss[cstorkey['name']] = settings
    if debug: print(json.dumps(t_cstor_ss, sort_keys=False, indent=4))
    return t_cstor_ss


def restart_services(provisioning):
    for key in provisioning:
        url = "https://{}/sys/20141028/restartAll".format(key['private_ip'])
        try:
            s = requests.get(url, auth=HTTPBasicAuth(user, password), verify=False)
        except requests.exceptions.RequestException as e:
            raise SystemExit(e)
        print("Restarting Services on {}".format(key['name']))


def add_devices_to_cclear(provisioning):
    for key in provisioning:
        print("adding {} to cclear: {}".format(key['name'], cclear_ip), end =": ")
        modify_payload = {'ip': key['private_ip'], 'name': key['name'], 'deviceType': 'cstor10', 'verify_ssl': False}
        modify_ss = post_request(url="https://{}/rt/data/cstor/modify".format(cclear_ip), post_payload=modify_payload)
        if debug: print(json.dumps(modify_ss.json(), sort_keys=False, indent=4))
        if 200 <= modify_ss.status_code <= 229:
            devauth_payload = {'devId': modify_ss.json()['_id'], "user": user, "pwd": password}
            devauth_ss = post_request(url="https://{}/rt/data/devauth/modify".format(cclear_ip), post_payload=devauth_payload)
            if debug: print(json.dumps(devauth_ss.json(), sort_keys=False, indent=4))
            if 200 <= devauth_ss.status_code <= 229:
                print("OK")
            else: 
                print("Failed {}".format(devauth_ss.status_code))
        elif modify_ss.status_code == 500:
            print("Device Already Exists - Skipping")
        else:
            print("Failed {}".format(modify_ss.status_code))
        

# Inputs

instruction = """
This script will configure the Azure Cloud products using the output from the ARM Templates.
After the ARM Template is finished deploying, copy/paste the output variables when prompted.

If the cVu deployment will be sending packet data to a 3rd packet tool, have the IP address(s) 
of the tools ready before running this script.

This script can be re-run to reconfigure the solution.
"""
print(instruction)

cclear_ip = environ.get('CCLEAR_IP') if environ.get('CCLEAR_IP') is not None else get_valid_ip("cclear_ip: ")
if debug: print(cclear_ip)

cvu_ilb_frontend_ip = environ.get('CVU_ILB_FRONTEND_IP') if environ.get('CVU_ILB_FRONTEND_IP') is not None else get_valid_ip("cvu_ilb_frontend_ip: ")
if debug: print(cvu_ilb_frontend_ip)

cvu_provisioning = json.loads(environ.get('CVU_PROVISIONING')) if environ.get('CVU_PROVISIONING') is not None else get_valid_json("cvu_provisioning: ")
if debug: print(cvu_provisioning)

cstor_ilb_frontend_ip = environ.get('CSTOR_ILB_FRONTEND_IP') if environ.get('CSTOR_ILB_FRONTEND_IP') is not None else get_valid_ip("cstor_ilb_frontend_ip: ")
if debug: print(cstor_ilb_frontend_ip)

cstor_provisioning = json.loads(environ.get('CSTOR_PROVISIONING')) if environ.get('CSTOR_PROVISIONING') is not None else get_valid_json("cstor_provisioning: ")
if debug: print(cstor_provisioning)
num_cstors = len(cstor_provisioning)

tool_ip_prompt = 'To provision the cvu to send to a packet based tool, enter space separated IP address(s). Leave blank for no tool provisioning. Example: 10.101.3.100 10.101.3.101: '
cvu_tool_ip = environ.get('CVU_TOOL_IP').split() if environ.get('CVU_TOOL_IP') is not None else get_valid_ips(tool_ip_prompt)
if debug: print(cvu_tool_ip)
num_tools = len(cvu_tool_ip)

user = environ.get('CPKT_USER') if environ.get('CPKT_USER') is not None else get_user("cClear Web UI Username: ")
password = environ.get('CPKT_PASSWORD') if environ.get('CPKT_PASSWORD') is not None else get_passwd("cClear Web UI Password: ")

# main 
cur_ss_cvu = get_system_settings(cvu_provisioning)
cur_ss_cstor = get_system_settings(cstor_provisioning)

cur_ss_cvu = set_system_settings(create_cvu_provisioining_settings(), cvu_provisioning)
if debug: print(json.dumps(cur_ss_cvu, sort_keys=False, indent=4))
cur_ss_cstor = set_system_settings(create_cstor_provisioning_settings(), cstor_provisioning)
if debug: print(json.dumps(cur_ss_cstor, sort_keys=False, indent=4))

restart_services(cvu_provisioning)
restart_services(cstor_provisioning)
print("Finished VXLAN provisioning")

add_devices_to_cclear(cstor_provisioning)
print("Finished cClear provisioning")
EOF_DEPLOYER
chmod +x /opt/cloud/deployer.py
