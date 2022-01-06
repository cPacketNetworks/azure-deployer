@description('Location for the resources.')
param location string

@description('User name for the Virtual Machine.')
param adminUsername string

@allowed([
  'password'
  'sshPublicKey'
])
@description('Type of authentication to use on the Virtual Machine.')
param authenticationType string

@secure()
@description('Password or ssh key for the Virtual Machine.')
param adminPasswordOrKey string

@description('virtualNetwork properties from VirtualNetworkCombo')
param virtualNetwork object

// cClear
@description('cclear VM size')
param cClearVMSize string

@description('Number of cClears')
param cClearCount int = 0

@description('cClear VM Name')
param cClearVmName string

@description('cClear Image URI')
param cClearImage object

@description('cClear Image Version')
param cClearImageURI string = ''

// cVu
@description('cvu VM size')
param cvuVMSize string

@description('Number of cVus')
param cvuCount int = 3

@description('cVu Base VM Name')
param cvuVmName string

@description('cvu Image URI')
param cvuImage object

@description('cvu Image Version')
param cVuImageURI string = ''

// cStor
@description('cvu VM size')
param cstorVMSize string

@description('Number of cStors')
param cstorCount int = 1

@description('cStor VM Name')
param cstorVmName string

@description('cStor Disk Count')
param cstorDiskCount int

@description('cStor Size Count')
param cstorDiskSize int

@description('cstor Image URI')
param cstorImage object

@description('cstor Image Version')
param cStorImageURI string = ''

@description('tags from TagsByResource')
param tagsByResource object

var cvulbName = '${cvuVmName}_iLB'
var cstorlbName = '${cstorVmName}_iLB'

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

var cstorilb_enabled = cstorCount > 1 ? true : false
var cvuilb_enabled = cvuCount > 1 ? true : false

var mgmtsubnetId = virtualNetwork.newOrExisting == 'new' ? mgmtsubnet.id : resourceId(virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, virtualNetwork.subnets.mgmtSubnet.name)
var monsubnetId = virtualNetwork.newOrExisting == 'new' ? monsubnet.id : resourceId(virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, virtualNetwork.subnets.monSubnet.name)
var toolssubnetId = virtualNetwork.newOrExisting == 'new' ? toolssubnet.id : resourceId(virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, virtualNetwork.subnets.toolsSubnet.name)

var cclearImageURI = empty(cClearImageURI) ? cClearImage.id : cClearImageURI
var cstorImageURI = empty(cStorImageURI) ? cstorImage.id : cStorImageURI
var cvuImageURI = empty(cVuImageURI) ? cvuImage.id : cVuImageURI

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetwork.addressPrefixes
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Network/virtualNetworks') ? tagsByResource['Microsoft.Network/virtualNetworks'] : null
}

resource mgmtsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.mgmtSubnet.name
  parent: vnet
  properties: {
    addressPrefix: virtualNetwork.subnets.mgmtSubnet.addressPrefix
  }
}

// The following resources are defined per subnet because we need to reference the subnets independently in other resources. 
//   This causes the ARM templates to execute this subnet creation operation in parallel. However, there is a race condition where 
//   subnets can't be executed at the same time.  In order to work around this, a explict dependency is created to serialize
//   the execution and prevent the subnets from failing creation. 

resource monsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.monSubnet.name
  parent: vnet
  properties: {
    addressPrefix: virtualNetwork.subnets.monSubnet.addressPrefix
  }
  dependsOn: [
    mgmtsubnet
  ]
}

resource toolssubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.toolsSubnet.name
  parent: vnet
  properties: {
    addressPrefix: virtualNetwork.subnets.toolsSubnet.addressPrefix
  }
  dependsOn: [
    monsubnet
  ]
}

/*
  cClear Section
*/

resource cclearnic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cClearCount): if (cClearCount > 0) {
  name: '${cClearVmName}-${i}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${cClearVmName}-${i}-ipconfig-nic'
        properties: {
          subnet: {
            id: mgmtsubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  tags: contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : null
}]

resource cclearvm 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, cClearCount): if (cClearCount > 0) {
  name: '${cClearVmName}-${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: cClearVMSize
    }
    storageProfile: {
      imageReference: {
        id: cclearImageURI
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        caching: 'ReadWrite'
      }
      dataDisks: [
        {
          name: '${cClearVmName}-${i}-DataDisk1'
          lun: 1
          createOption: 'Empty'
          diskSizeGB: 500
          caching: 'ReadWrite'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: cclearnic[i].id
        }
      ]
    }
    osProfile: {
      computerName: '${cClearVmName}-${i}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: any(authenticationType == 'password' ? null : linuxConfiguration) // TODO: workaround for https://github.com/Azure/bicep/issues/449
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Compute/virtualMachines') ? tagsByResource['Microsoft.Compute/virtualMachines'] : null
}]

/*
  cStor Section
*/

resource cstorcapturenic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cstorCount): if (cstorCount > 0) {
  name: '${cstorVmName}-${i}-capture-nic'
  location: location
  dependsOn: any(cstorilb_enabled) ? [
    cstorlb01
  ] : []
  properties: {
    ipConfigurations: [
      {
        name: '${cstorVmName}-${i}-capture-ipconfig-nic'
        properties: {
          subnet: {
            id: toolssubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: any(cstorilb_enabled) ? [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', cstorlbName, '${cstorlbName}-backend')
            }
          ] : []
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: true
  }
  tags: contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : null
}]

resource cstormgmtnic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cstorCount): if (cstorCount > 0) {
  name: '${cstorVmName}-${i}-mgmt-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${cstorVmName}-${i}-mgmt-ipconfig-nic'
        properties: {
          subnet: {
            id: mgmtsubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  tags: contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : null
}]

resource cstorvm 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, cstorCount): if (cstorCount > 0) {
  name: '${cstorVmName}-${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: cstorVMSize
    }
    storageProfile: {
      imageReference: {
        id: cstorImageURI
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        caching: 'ReadWrite'
      }
      dataDisks: [ for j in range(0, cstorDiskCount): {
        name: '${cstorVmName}-${i}-DataDisk-${j}'
        lun: j
        createOption: 'Empty'
        diskSizeGB: cstorDiskSize
        caching: 'ReadWrite'
      }]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: cstormgmtnic[i].id
          properties: {
            primary: true
          }
        }
        {
          id: cstorcapturenic[i].id
          properties: {
            primary: false
          }
        }
      ]
    }
    osProfile: {
      computerName: '${cstorVmName}-${i}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: any(authenticationType == 'password' ? null : linuxConfiguration) // TODO: workaround for https://github.com/Azure/bicep/issues/449
      customData: loadFileAsBase64('./userdata-cstor.bash')
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Compute/virtualMachines') ? tagsByResource['Microsoft.Compute/virtualMachines'] : null
}]

resource cvucapturenic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cvuCount): if (cvuCount > 0) {
  name: '${cvuVmName}-${i}-capture-nic'
  location: location
  dependsOn: any(cvuilb_enabled) ? [
    cvulb01
  ] : []
  properties: {
    ipConfigurations: [
      {
        name: '${cvuVmName}-${i}-capture-ipconfig-nic'
        properties: {
          subnet: {
            id: monsubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: any(cvuilb_enabled) ? [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', cvulbName, '${cvulbName}-backend')
            }
          ] : []
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: true
  }
  tags: contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : null
}]

resource cvumgmtnic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cvuCount): if (cvuCount > 0) {
  name: '${cvuVmName}-${i}-mgmt-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${cvuVmName}-${i}-mgmt-ipconfig-nic'
        properties: {
          subnet: {
            id: mgmtsubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  tags: contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : null
}]

resource cvuvm 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, cvuCount): if (cvuCount > 0) {
  name: '${cvuVmName}-${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: cvuVMSize
    }
    storageProfile: {
      imageReference: {
        id: cvuImageURI
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        caching: 'ReadWrite'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: cvumgmtnic[i].id
          properties: {
            primary: true
          }
        }        
        {
          id: cvucapturenic[i].id
          properties: {
            primary: false
          }
        }
      ]
    }
    osProfile: {
      computerName: '${cvuVmName}-${i}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: any(authenticationType == 'password' ? null : linuxConfiguration) // TODO: workaround for https://github.com/Azure/bicep/issues/449
      customData: loadFileAsBase64('./userdata-cvu.bash')
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Compute/virtualMachines') ? tagsByResource['Microsoft.Compute/virtualMachines'] : null
}]

resource cvulb01 'Microsoft.Network/loadBalancers@2021-03-01' = if (cvuilb_enabled) {
  name: cvulbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: '${cvulbName}-frontend'
        properties: {
          subnet: {
            id: monsubnetId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: '${cvulbName}-backend'
      }
    ]
    loadBalancingRules: [
      {
        name: '${cvulbName}-to_server'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', cvulbName, '${cvulbName}-frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', cvulbName, '${cvulbName}-backend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', cvulbName, '${cvulbName}-probe')
          }
          frontendPort: 0
          backendPort: 0
          protocol: 'All'
        }
      }
    ]
    probes: [
      {
        name: '${cvulbName}-probe'
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
  tags: contains(tagsByResource, 'Microsoft.Network/loadBalancers') ? tagsByResource['Microsoft.Network/loadBalancers'] : null
}

resource cstorlb01 'Microsoft.Network/loadBalancers@2021-03-01' = if (cstorilb_enabled) {
  name: cstorlbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: '${cstorlbName}-frontend'
        properties: {
          subnet: {
            id: toolssubnetId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: '${cstorlbName}-backend'
      }
    ]
    loadBalancingRules: [
      {
        name: '${cstorlbName}-to_server'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', cstorlbName, '${cstorlbName}-frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', cstorlbName, '${cstorlbName}-backend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', cstorlbName, '${cstorlbName}-probe')
          }
          frontendPort: 0
          backendPort: 0
          protocol: 'All'
        }
      }
    ]
    probes: [
      {
        name: '${cstorlbName}-probe'
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
  tags: contains(tagsByResource, 'Microsoft.Network/loadBalancers') ? tagsByResource['Microsoft.Network/loadBalancers'] : null
}


output cclear_mgmt_urls array = [for i in range(0, cClearCount): {
  '${cclearnic[i].name}': 'https://${cclearnic[i].properties.ipConfigurations[0].properties.privateIPAddress}'
}]

output cvu_ilb_frontend_ip string = cvuilb_enabled ? cvulb01.properties.frontendIPConfigurations[0].properties.privateIPAddress : ''
output cvu_mgmt_urls array = [for i in range(0, cvuCount): {
  '${cvumgmtnic[i].name}': 'https://${cvumgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}'
}]
output cvu_capture_ips array = [for i in range(0, cvuCount): {
  '${cvucapturenic[i].name}': '${cvucapturenic[i].properties.ipConfigurations[0].properties.privateIPAddress}'
}]

output cstor_ilb_frontend_ip string = cstorilb_enabled ? cstorlb01.properties.frontendIPConfigurations[0].properties.privateIPAddress : ''
output cstor_mgmt_urls array = [for i in range(0, cstorCount): {
  '${cstormgmtnic[i].name}': 'https://${cstormgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}'
}]
output cstor_capture_ips array = [for i in range(0, cstorCount): {
  '${cstorcapturenic[i].name}': '${cstorcapturenic[i].properties.ipConfigurations[0].properties.privateIPAddress}'
}]

output cvu_provisioning_vxlan0 array = [for i in range(0, cvuCount): {
  '${cvumgmtnic[i].name}' : 'https://${cvumgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}/sys/10/updateASingleSystemSetting?cvuv_vxlan_srcip_0=${cvucapturenic[i].properties.ipConfigurations[0].properties.privateIPAddress}&cvuv_vxlan_remoteip_0=<MY_TOOL_IP>'
}]

output cvu_provisioning_vxlan1 array = [for i in range(0, cvuCount): {
  '${cvumgmtnic[i].name}' : 'https://${cvumgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}/sys/10/updateASingleSystemSetting?cvuv_vxlan_srcip_1=${cvucapturenic[i].properties.ipConfigurations[0].properties.privateIPAddress}&cvuv_vxlan_remoteip_1=<MY_TOOL_IP>'
}]

// add cvu & cstor stats-db 
output cvu_provisioning_statsdb array = [for i in range(0, cvuCount): {
  '${cvumgmtnic[i].name}' : 'https://${cvumgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}/sys/10/updateASingleSystemSetting?stats_db_server=${cclearnic[0].properties.ipConfigurations[0].properties.privateIPAddress}'
}]

output cvu_provisioning_restart array = [for i in range(0, cvuCount): {
  '${cvumgmtnic[i].name}' : 'https://${cvumgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}/sys/20141028/restartAll'
}]

output cstor_provisioning_statsdb array = [for i in range(0, cstorCount): {
  '${cstormgmtnic[i].name}': 'https://${cstormgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}/sys/10/updateASingleSystemSetting?stats_db_server=${cclearnic[0].properties.ipConfigurations[0].properties.privateIPAddress}'
}]

output cstor_provisioning_restart array = [for i in range(0, cstorCount): {
  '${cstormgmtnic[i].name}' : 'https://${cstormgmtnic[i].properties.ipConfigurations[0].properties.privateIPAddress}/sys/20141028/restartAll'
}]
