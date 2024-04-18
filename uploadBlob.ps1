<#PSScriptInfo
.Synopsis
   Powershell script to upload a file to a blob storage account
.INPUTS
   The input to this script are the environment variables set by the DeploymentScript Bicep resource
.OUTPUTS
   The output of this script is returned as a DeploymentScript output ($DeploymentScriptOutputs) as the 'text' key.
   This is later interpreted by the DeploymentScript to get the Uri of the uploaded file.
.NOTES
  Version:        0.1
  Author:         Ben Roberts
  Creation Date:  17/04/2024
  Purpose/Change: Initial script development
.
#>

# Connect to Azure using Managed Identity deficed in the Deployment Script resource
try {
    Connect-AzAccount -Identity
}
catch {
    Write-Host "Failed to connect to Azure"
    exit 1
}

# Get the storage account context
$saContext = Get-AzStorageAccount -Name "${env:AZURE_STORAGE_ACCOUNT}" -ResourceGroupName "${env:AZURE_RESOURCE_GROUP}"
$workingContext = $saContext.Context

# Output the script from the environment variable to a file
Write-Output "${env:CONTENT}" > ConfigureWebServer_base.ps1 

# Upload the file to the blob storage account
try {
    $output = Set-AzStorageBlobContent -File ConfigureWebServer_base.ps1 -Container dsc -Blob ConfigureWebServer_base.ps1 -Context $workingContext -Force
}
catch {
    Write-Host $Error[0].Exception.Message
}

# Output the results to the built-in DeploymentScript variable using the 'text' key
$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['text'] = $output
# See results.json for an example of $output