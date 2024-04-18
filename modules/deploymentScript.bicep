param location string = ''
param umiId string = ''
param storageAccountName string = ''


// Deployment Script for VM Extension
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'inlinePS'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    // User Assigned Identity for the Deployment Script to access the Storage Account
    userAssignedIdentities: {
      '${umiId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.4'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccountName
      }
      {
        name: 'CONTENT'
        // Imports the content of a file - in this case, the PowerShell script
        // that will be uploaded to the Storage Account
        // This is stored as a Environment Variable in the deploymentScripts
        // environment as a string
        value: loadTextContent('../ConfigureWebServer_base.ps1')
      }
      {
        name: 'AZURE_RESOURCE_GROUP'
        value: resourceGroup().name
      }
    ]
    // arguments: saName
    scriptContent: loadTextContent('../uploadBlob.ps1')
  }
}

output result string = deploymentScript.properties.outputs.text.ICloudBlob.Uri
