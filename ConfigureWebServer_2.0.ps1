Configuration ConfigureWebServer
{
    # Import the required module
    Import-Module PSDesiredStateConfiguration
    Import-Module WebAdministrationDsc
    Import-Module NetworkingDsc

    Invoke-DscResource -Name WindowsFeature -ModuleName PSDesiredStateConfiguration -Method Set -Property @{
        Name   = "Web-Server"
        Ensure = "Present"
    } -Verbose

    # Configure Website
    Invoke-DscResource -Name WebSiteDefaults -ModuleName WebAdministrationDsc -Method Set -Property @{
        IsSingleInstance       = 'Yes'
        LogFormat              = 'IIS'
        LogDirectory           = 'C:\inetpub\logs\LogFiles'
        TraceLogDirectory      = 'C:\inetpub\logs\FailedReqLogFiles'
        DefaultApplicationPool = 'DefaultAppPool'
        AllowSubDirConfig      = 'true'
        DependsOn              = "[WindowsFeature]IIS"
    } -Verbose

    # Allow inbound traffic on port 80
    Invoke-DscResource -Name Firewall -ModuleName NetworkingDsc -Method Set -Property @{
        Name      = "Allow Inbound Port 80"
        Direction = "Inbound"
        RemotePort = ('80')
        LocalPort  = ('80')
        Protocol  = "TCP"
        Action    = "Allow"
        Enabled   = "True"
    } -Verbose

    # Disable Unused Services
    $unusedServices = @("Fax", "WebClient", "IISAdmin", "WindowsMediaPlayer", "NetMeeting")
    foreach ($service in $unusedServices) {
        Invoke-DscResource -Name Service -ModuleName PSDesiredStateConfiguration -Method Set -Property @{
            Name        = $service
            State       = "Stopped"
            StartupType = "Disabled"
        } -Verbose
    }
}

ConfigureWebServer