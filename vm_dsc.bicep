@description('Username for the Virtual Machine.')
param adminUsername string

@description('Password for the Virtual Machine.')
@minLength(12)
@secure()
param adminPassword string

@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsLabelPrefix string = toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')

@description('Name for the Public IP used to access the Virtual Machine.')
param publicIpName string = 'myPublicIP'

@description('Allocation method for the Public IP used to access the Virtual Machine.')
@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Dynamic'

@description('SKU for the Public IP used to access the Virtual Machine.')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Basic'

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
@allowed([
  '2016-datacenter-gensecond'
  '2016-datacenter-server-core-g2'
  '2016-datacenter-server-core-smalldisk-g2'
  '2016-datacenter-smalldisk-g2'
  '2016-datacenter-with-containers-g2'
  '2016-datacenter-zhcn-g2'
  '2019-datacenter-core-g2'
  '2019-datacenter-core-smalldisk-g2'
  '2019-datacenter-core-with-containers-g2'
  '2019-datacenter-core-with-containers-smalldisk-g2'
  '2019-datacenter-gensecond'
  '2019-datacenter-smalldisk-g2'
  '2019-datacenter-with-containers-g2'
  '2019-datacenter-with-containers-smalldisk-g2'
  '2019-datacenter-zhcn-g2'
  '2022-datacenter-azure-edition'
  '2022-datacenter-azure-edition-core'
  '2022-datacenter-azure-edition-core-smalldisk'
  '2022-datacenter-azure-edition-smalldisk'
  '2022-datacenter-core-g2'
  '2022-datacenter-core-smalldisk-g2'
  '2022-datacenter-g2'
  '2022-datacenter-smalldisk-g2'
])
param OSVersion string = '2022-datacenter-azure-edition'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_D2s_v5'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the virtual machine.')
param vmName string = 'simple-vm'

@description('This is the built-in Storage Blob Data Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles')
resource storageBlobContributorRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

@description('Command to execute on the Virtual Machine.')
param commandToExecute string = 'powershell -File ConfigureWebServer_base.ps1'

@description('VM Extension Properties.')
param extentionsProperties object = {
  extensionName: 'IIS'
  publisher: 'Microsoft.Compute'
  type: 'CustomScriptExtension'
  typeHandlerVersion: '1.10'
}

var nicName = 'myVMNic'
var networkSecurityGroupName = 'default-NSG'
var saName = '${vmName}${uniqueString(resourceGroup().id)}'

// Create Network components
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: 'virtualNetworkDeployment'
  params: {
    // Required parameters
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    name: 'nvnmin001'
    // Non-required parameters
    location: location
    subnets: [
      {
        addressPrefix: '10.0.1.0/24'
        name: 'sbnmin001'
      }
      {
        addressPrefix: '10.0.2.0/24'
        name: 'bastion001'
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: 'networkSecurityGroupDeployment'
  params: {
    // Required parameters
    name: networkSecurityGroupName
    // Non-required parameters
    location: location
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'default-allow-80'
        properties: {
          priority: 1001
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: virtualNetwork.outputs.subnetResourceIds[0]
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Create User Assigned Identity for RBAC for VM to Storage Account
// and for Deployment Script
resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  location: location
  name: 'miuaimin001'
}

// Create Storage Account for scripts
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: saName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${umi.id}': {}
    }
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: false
      allowPermanentDelete: true
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'dsc'
  parent: blob
  properties: {
    publicAccess: 'Blob'
  }
}

// Assign the UMI the Storage Account Contributor role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, umi.id, storageBlobContributorRole.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobContributorRole.id
    principalId: umi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deployment Script for VM Extension
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'inlinePS'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    // User Assigned Identity for the Deployment Script to access the Storage Account
    userAssignedIdentities: {
      '${umi.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.4'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccount.name
      }
      {
        name: 'CONTENT'
        // Imports the content of a file - in this case, the PowerShell script
        // that will be uploaded to the Storage Account
        // This is stored as a Environment Variable in the deploymentScripts
        // environment as a string
        value: loadTextContent('ConfigureWebServer_base.ps1')
      }
      {
        name: 'AZURE_RESOURCE_GROUP'
        value: resourceGroup().name
      }
    ]
    // arguments: saName
    scriptContent: loadTextContent('uploadBlob.ps1')
  }
  dependsOn: [
    // This ensures that the Storage Account and role assignment are created before the deployment script
    roleAssignment
  ]
}

// Create Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${umi.id}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      adminUsername: adminUsername
      adminPassword: adminPassword
      computerName: vmName
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        offer: 'WindowsServer'
        publisher: 'MicrosoftWindowsServer'
        sku: OSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
  dependsOn: [
    deploymentScript
  ]
}

// Create VM Extension  
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: extentionsProperties.extensionName
  location: location
  properties: {
    publisher: extentionsProperties.publisher
    type: extentionsProperties.type
    typeHandlerVersion: extentionsProperties.version
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        // Uri derived from the output of the deployment script: See uploadBlob.ps1
        deploymentScript.properties.outputs.text.ICloudBlob.Uri
      ]
      commandToExecute: commandToExecute
    }
  }
}

output result string = deploymentScript.properties.outputs.text.ICloudBlob.Uri
output publicIP string = publicIp.properties.ipAddress
