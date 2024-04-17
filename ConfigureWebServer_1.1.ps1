Install-Module PSDesiredStateConfiguration -Force -RequiredVersion 2.0.7
Install-Module -Name GuestConfiguration -Force -RequiredVersion 4.5.0

$PS7Url = "https://github.com/PowerShell/PowerShell/releases/latest"
$PS7LatestVersion = (Invoke-WebRequest -Uri $PS7url).Content | Select-String -Pattern "[0-9]+\.[0-9]+\.[0-9]+" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$PS7DownloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$PS7LatestVersion/PowerShell-$PS7LatestVersion-win-x64.msi"
Invoke-WebRequest -Uri $PS7DownloadUrl -OutFile $env:TEMP\ps7.msi
$PS7ProductId = (Get-MSIProperty -Path $env:TEMP\ps7.msi -Property ProductCode).Value
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/cloudacademy/static-website-example/master/index.html" -OutFile "$env:TEMP\index.html"

Configuration ConfigureWebServer
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration -ModuleVersion 2.0.7
    Import-DscResource -ModuleName NetworkingDsc

    Node localhost
    {   
        # Install PowerShell 7
        MsiPackage PowerShell7 {
            Ensure    = "Present"
            Path      = $PS7DownloadUrl
            ProductId = $PS7ProductId
        }

        # Install IIS Role and Features
        WindowsFeature IIS {
            Ensure = "Present"
            Name   = "Web-Server"
        }

        # Allow inbound traffic on port 80
        Firewall AllowInboundPort80 {
            Name       = "Allow Inbound Port 80"
            Direction  = "Inbound"
            RemotePort = ('80')
            LocalPort  = ('80')
            Protocol   = "TCP"
            Action     = "Allow"
            Enabled    = "True"
            Ensure     = "Present"
        }

        # Disable Unused Services
        $unusedServices = @("tapisrv", "WMPNetworkSvc", "ssh-agent")
        foreach ($service in $unusedServices) {
            Service $service {
                Name        = $service
                State       = "Stopped"
                StartupType = "Disabled"
            }
        }
        # Download index.html
        File CopyIndexHtml {
            Ensure          = "Present"
            Type            = "File"
            SourcePath      = "$env:TEMP\index.html"
            DestinationPath = "C:\inetpub\wwwroot\index.html"
        }
    }
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
        }
    )
}

$OutputPath = "$HOME/arc_automanage_machine_configuration_custom_windows"
New-Item $OutputPath -Force -ItemType Directory

ConfigureWebServer -ConfigurationData $ConfigurationData -OutputPath $OutputPath