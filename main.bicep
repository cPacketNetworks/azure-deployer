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

var cclear_enabled = cClearCount > 0 ? true : false
var cvu_enabled = cvuCount > 0 ? true : false
var cstor_enabled = cstorCount > 0 ? true : false

var cstorilb_enabled = cstorCount > 1 ? true : false
var cvuilb_enabled = cvuCount > 1 ? true : false

var monsubnetId = virtualNetwork.newOrExisting == 'new' ? monsubnet.id : resourceId(virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, virtualNetwork.subnets.monSubnet.name)

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

resource monsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.monSubnet.name
  parent: vnet
  properties: {
    addressPrefix: virtualNetwork.subnets.monSubnet.addressPrefix
  }
}

/*
  cClear Section
*/

resource cclearnic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cClearCount): if (cclear_enabled) {
  name: '${cClearVmName}-${i}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${cClearVmName}-${i}-ipconfig-nic'
        properties: {
          subnet: {
            id: monsubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
  tags: contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : null
}]

resource cclearvm 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, cClearCount): if (cclear_enabled) {
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
      customData: loadFileAsBase64('./userdata-cclear.bash')
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Compute/virtualMachines') ? tagsByResource['Microsoft.Compute/virtualMachines'] : null
}]

/*
  cStor Section
*/

resource cstorcapturenic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cstorCount): if (cstor_enabled) {
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
            id: monsubnetId
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

resource cstorvm 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, cstorCount): if (cstor_enabled) {
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
          id: cstorcapturenic[i].id
          properties: {
            primary: true
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

resource cvucapturenic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, cvuCount): if (cvu_enabled) {
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

resource cvuvm 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, cvuCount): if (cvu_enabled) {
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
            id: monsubnetId
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

output To_Finish_Provisioning string = cclear_enabled ? 'ssh ${adminUsername}@${cclearnic[0].properties.ipConfigurations[0].properties.privateIPAddress}' : 'No cClear is Deployed. There is no action to take.'
output Copy_This_and_Paste_Into_ssh_Prompt string = cclear_enabled ? 'until [ -x /opt/cloud/deployer.py ]; do echo "still deploying, please wait..."; sleep 5; done; /opt/cloud/deployer.py' : 'No cClear is Deployed. There is no action to take.'
output cclear_ip string = cclear_enabled ? cclearnic[0].properties.ipConfigurations[0].properties.privateIPAddress : ''

output cvu_ilb_frontend_ip string = cvuilb_enabled ? cvulb01.properties.frontendIPConfigurations[0].properties.privateIPAddress : ''
output cvu_provisioning array = [for i in range(0, cvuCount): cvu_enabled ? {
  'index': i
  'name': '${cvuvm[i].name}'
  'nic_name': '${cvucapturenic[i].name}'
  'private_ip': '${cvucapturenic[i].properties.ipConfigurations[0].properties.privateIPAddress}'
} : []]

output cstor_ilb_frontend_ip string = cstorilb_enabled ? cstorlb01.properties.frontendIPConfigurations[0].properties.privateIPAddress : ''
output cstor_provisioning array = [for i in range(0, cstorCount): cstor_enabled ? {
  'index': i
  'name': '${cstorvm[i].name}'
  'nic_name': '${cstorcapturenic[i].name}'
  'private_ip': '${cstorcapturenic[i].properties.ipConfigurations[0].properties.privateIPAddress}'
} : []]
