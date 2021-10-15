
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
param tagsByResource array

