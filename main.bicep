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

/*
@description('storageAccount properties from storageAccountSelector')
param storageAccount object
*/

@description('virtualNetwork properties from VirtualNetworkCombo')
param virtualNetwork object

@description('cClear VM Name')
param cClearVmName string

@description('defualt values for cclear VM')
param VMSizeSettings object = {
  cclear: 'Standard_D4s_v3'
  cvu: 'Standard_D4s_v3'
  cstor: 'Standard_D4s_v3'
}

@description('public IP properties from PublicIpAddressCombo')
param cclearPublicIpAddress01 object

@description('cClear Image URI')
param cClearImage object

@description('cClear Image Version')
param cClearVersion string = ''

@description('cVu Base VM Name')
param cvuVmName string

@description('public IP properties from PublicIpAddressCombo')
param cvuPublicIpAddress01 object

@description('public IP properties from PublicIpAddressCombo')
param cvuPublicIpAddress02 object

@description('public IP properties from PublicIpAddressCombo')
param cvuPublicIpAddress03 object

@description('cvu Image URI')
param cvuImage object

@description('cvu Image Version')
param cvuVersion string = ''

@description('cStor VM Name')
param cstorVmName string

@description('public IP properties from PublicIpAddressCombo')
param cstorPublicIpAddress01 object

@description('cstor Image URI')
param cstorImage object

@description('cstor Image Version')
param cstorVersion string = ''

@description('tags from TagsByResource')
param tagsByResource object

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

// var storageAccountId = storageAccount.newOrExisting == 'new' ? sa.id : resourceId(storageAccount.resourceGroup, 'Microsoft.Storage/storageAccounts/', storageAccount.name)

var mgmtsubnetId = virtualNetwork.newOrExisting == 'new' ? mgmtsubnet.id : resourceId(virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, virtualNetwork.subnets.mgmtSubnet.name)
var monsubnetId = virtualNetwork.newOrExisting == 'new' ? monsubnet.id : resourceId(virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, virtualNetwork.subnets.monSubnet.name)
var cstorsubnetId = virtualNetwork.newOrExisting == 'new' ? cstorsubnet.id : resourceId(virtualNetwork.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, virtualNetwork.subnets.cstorSubnet.name)

var cclearpublicIPId = cclearPublicIpAddress01.newOrExistingOrNone == 'new' ? cclearpip01.id : resourceId(cclearPublicIpAddress01.resourceGroup, 'Microsoft.Network/publicIPAddresses', cclearPublicIpAddress01.name)
var cclearImageURI = empty(cClearVersion) ? cClearImage.id : '${cClearImage.id}/versions/${cClearVersion}'

/*
resource sa 'Microsoft.Storage/storageAccounts@2021-04-01' = if (storageAccount.newOrExisting == 'new') {
  kind: storageAccount.kind
  location: location
  name: storageAccount.name
  sku: {
    name: storageAccount.type
  }
  tags: contains(tagsByResource, 'Microsoft.Storage/storageAccounts') ? tagsByResource['Microsoft.Storage/storageAccounts'] : null
}
*/

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

resource monsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.monSubnet.name
  parent: vnet
  properties: {
    addressPrefix: virtualNetwork.subnets.monSubnet.addressPrefix
  }
}

resource cstorsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.cstorSubnet.name
  parent: vnet
  properties: {
    addressPrefix: virtualNetwork.subnets.cstorSubnet.addressPrefix
  }
}

/*
  cClear Section
*/

resource cclearpip01 'Microsoft.Network/publicIPAddresses@2020-11-01' = if (cclearPublicIpAddress01.newOrExistingOrNone == 'new') {
  name: cclearPublicIpAddress01.name
  location: location
  properties: {
    publicIPAllocationMethod: cclearPublicIpAddress01.publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: cclearPublicIpAddress01.domainNameLabel
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Network/publicIPAddresses') ? tagsByResource['Microsoft.Network/publicIPAddresses'] : null
}

resource cclearnic01 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${cClearVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${cClearVmName}-ipconfig-nic'
        properties: {
          subnet: {
            id: mgmtsubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: any(cclearPublicIpAddress01.newOrExistingOrNone == 'none' ? null : cclearpublicIPId)
          }
        }
      }
    ]
  }
  tags: contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : null
}

resource cclearvm01 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: cClearVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: VMSizeSettings.cclear
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
          name: '${cClearVmName}-DataDisk1'
          lun: 1
          createOption: 'Empty'
          diskSizeGB: 500
          writeAcceleratorEnabled: true
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: cclearnic01.id
        }
      ]
    }
    osProfile: {
      computerName: cClearVmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: any(authenticationType == 'password' ? null : linuxConfiguration) // TODO: workaround for https://github.com/Azure/bicep/issues/449
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Compute/virtualMachines') ? tagsByResource['Microsoft.Compute/virtualMachines'] : null
}
