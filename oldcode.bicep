// resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
//   name: networkSecurityGroupName
//   location: location
//   properties: {
//     securityRules: [
//       {
//         name: 'default-allow-3389'
//         properties: {
//           priority: 1000
//           access: 'Allow'
//           direction: 'Inbound'
//           destinationPortRange: '3389'
//           protocol: 'Tcp'
//           sourcePortRange: '*'
//           sourceAddressPrefix: '*'
//           destinationAddressPrefix: '*'
//         }
//       }
//       {
//         name: 'default-allow-80'
//         properties: {
//           priority: 1001
//           access: 'Allow'
//           direction: 'Inbound'
//           destinationPortRange: '80'
//           protocol: 'Tcp'
//           sourcePortRange: '*'
//           sourceAddressPrefix: '*'
//           destinationAddressPrefix: '*'
//         }
//       }
//     ]
//   }
// }

// module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.3' = {
//   name: vmName
//   params: {
//     // Required parameters
//     managedIdentities: {
//       userAssignedResourceIds: [
//         umi.id
//       ]
//     }
//     adminUsername: adminUsername
//     availabilityZone: 0
//     encryptionAtHost: false
//     extensionCustomScriptConfig: {
//       enabled: true
//       fileData: [
//         {
//           uri: 'https://${saName}.blob.core.windows.net/dsc/ConfigureWebServer_base.ps1'
//           storageAccountId: ''
//         }
//       ]
//       settings: {
//         commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ConfigureWebServer_base.ps1'
//       }
//     }
//     imageReference: {
//       offer: 'WindowsServer'
//       publisher: 'MicrosoftWindowsServer'
//       sku: '2022-datacenter-azure-edition'
//       version: 'latest'
//     }
//     name: vmName
//     nicConfigurations: [
//       {
//         enablePublicIP: true
//         enableAcceleratedNetworking: false
//         ipConfigurations: [
//           {
//             name: 'ipconfig01'
//             subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
//             pipConfiguration: {
//               publicIpNameSuffix: '-pip-01'
//             }
//           }
//         ]

//         nicSuffix: '-nic-01'
//       }
//     ]
//     osDisk: {
//       caching: 'ReadWrite'
//       diskSizeGB: '128'
//       managedDisk: {
//         storageAccountType: 'StandardSSD_LRS'
//       }
//     }
//     osType: 'Windows'
//     vmSize: vmSize
//     // Non-required parameters
//     adminPassword: adminPassword
//     location: location
//   }
//   dependsOn: [
//     deploymentScript
//   ]
// }

module storageAccount 'br/public:avm/res/storage/storage-account:0.8.2' = {
  name: 'storageAccountDeployment'
  params: {
    // Required parameters
    name: saName
    // Non-required parameters
    kind: 'BlobStorage'
    blobServices: {
      containers: [
        {
          name: 'dsc'
          roleAssignments: [
            {
              principalId: umi.properties.principalId
              principalType: 'ServicePrincipal'
              roleDefinitionIdOrName: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
            }
          ]
        }
      ]
    }
    managedIdentities: {
      userAssignedResourceIds: [
        umi.id
      ]
    }
    location: location
    skuName: 'Standard_LRS'
    publicNetworkAccess: 'Enabled'
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}
