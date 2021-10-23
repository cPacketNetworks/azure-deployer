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

@description('storageAccount properties from storageAccountSelector')
param storageAccount object

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

@description('cVu Base VM Name')
param cvuVmName string

@description('public IP properties from PublicIpAddressCombo')
param cvuPublicIpAddress01 object

@description('public IP properties from PublicIpAddressCombo')
param cvuPublicIpAddress02 object

@description('public IP properties from PublicIpAddressCombo')
param cvuPublicIpAddress03 object

@description('cStor VM Name')
param cstorVmName string

@description('public IP properties from PublicIpAddressCombo')
param cstorPublicIpAddress01 object

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

resource sa 'Microsoft.Storage/storageAccounts@2021-04-01' = if (storageAccount.newOrExisting == 'new') {
  kind: storageAccount.kind
  location: location
  name: storageAccount.name
  sku: storageAccount.type
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetwork.addressPrefixes
    }
  }
}

resource mgmtsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.mgmtSubnet.name
  properties: {
    addressPrefix: virtualNetwork.subnets.mgmtSubnet.addressPrefix
  }
}

resource monsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.monSubnet.name
  properties: {
    addressPrefix: virtualNetwork.subnets.monSubnet.addressPrefix
  }
}

resource cstorsubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = if (virtualNetwork.newOrExisting == 'new') {
  name: virtualNetwork.subnets.cstorSubnet.name
  properties: {
    addressPrefix: virtualNetwork.subnets.cstorSubnet.addressPrefix
  }
}

resource cclearpip 'Microsoft.Network/publicIPAddresses@2020-11-01' = if (cclearPublicIpAddress01.newOrExistingOrNone == 'new') {
  name: cvuPublicIpAddress01.name
  properties: {
    publicIPAllocationMethod: cvuPublicIpAddress01.publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: cvuPublicIpAddress01.domainNameLabel
    }
  }
}

resource cclearnic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${cClearVmName}-nic'
  properties: {
    ipConfigurations: [
      {
        name: '${cClearVmName}-ipconfig-nic'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${mgmtsubnet.name}'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: any(cclearPublicIpAddress01.newOrExistingOrNone == 'none' ? null : cclearpip.id)
          }
        }
      }
    ]
  }
}

// cstor_image_id  = "/subscriptions/${var.cpacket_shared_images_subscription_id}/resourceGroups/${var.cstor_image.resource_group_name}/providers/Microsoft.Compute/galleries/${var.cstor_image.gallery_name}/images/${var.cstor_image.image_definition}/versions/${var.cstor_image.image_version}"
// cvu_image_id    = "/subscriptions/${var.cpacket_shared_images_subscription_id}/resourceGroups/${var.cvu_image.resource_group_name}/providers/Microsoft.Compute/galleries/${var.cvu_image.gallery_name}/images/${var.cvu_image.image_definition}/versions/${var.cvu_image.image_version}"
// cclear_image_id = "/subscriptions/${var.cpacket_shared_images_subscription_id}/resourceGroups/${var.cclear_image.resource_group_name}/providers/Microsoft.Compute/galleries/${var.cclear_image.gallery_name}/images/${var.cclear_image.image_definition}/versions/${var.cclear_image.image_version}"

resource cclearvm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: cClearVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: VMSizeSettings.cclear
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        image: {
          uri: '/subscriptions/93004638-8c6b-4e33-ba58-946afd57efdf/resourceGroups/cstor-aidsinga-rg1/providers/Microsoft.Compute/galleries/cpacketccloudpre/images/cclearvpre/versions/0.0.4'
          // uri: '/subscriptions/${var.cpacket_shared_images_subscription_id}/resourceGroups/${var.cclear_image.resource_group_name}/providers/Microsoft.Compute/galleries/${var.cclear_image.gallery_name}/images/${var.cclear_image.image_definition}/versions/${var.cclear_image.image_version}'
        }
      }
      dataDisks: [
        {
          name: '${cClearVmName}-DataDisk1'
          lun: 1
          createOption: 'Empty'
          diskSizeGB: 500
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: cclearnic.id
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
}

resource applyTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  properties: {
    tags: tagsByResource
  }
}
