@{

    RootModule = 'StreamXRef.psm1'

    Author = 'Alex Wiser'

    CompanyName = 'Alex Wiser'

    ModuleVersion = '3.0.0'

    GUID = '8c89ef10-5110-4406-a876-82b8eadf5bb2'

    Copyright = 'Copyright 2020 Alex Wiser. Licensed under MIT license.'

    Description = 'Given a Twitch clip or video timestamp URL, get a URL to the same moment from the cross-referenced video or channel.'

    PowerShellVersion = '5.1'

    DotNetFrameworkVersion = '4.7.1'

    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @('Find-TwitchXRef', 'Export-XRefLookupData', 'Import-XRefLookupData', 'Clear-XRefLookupData')

    AliasesToExport = @('txr')

    VariablesToExport = @('')

    # PowerShell Gallery: Define your module's metadata
    PrivateData = @{
        PSData = @{

            Tags = @('Stream', 'Twitch', 'Cross-Reference', 'Reference', 'Rest', 'API', 'Find', 'Search',
                'PSEdition_Desktop', 'PSEdition_Core', 'Windows', 'Linux', 'Mac')

            LicenseUri = 'https://github.com/awsr/PS-StreamXRef/blob/master/LICENSE'

            ProjectUri = 'https://github.com/awsr/PS-StreamXRef'

            IconUri = ''

            ReleaseNotes = @'
## 3.0.0

First version released as a full PowerShell Module.

* Renamed module to "StreamXRef" due to Twitch's limitiations on project names
* Renamed `Get-TwitchXRef` to `Find-TwitchXRef`
* Changed alias from `gtxr` to `txr`
* Added data caching
* Added `Export-XRefLookupData`, `Import-XRefLookupData`, and `Clear-XRefLookupData`
'@

            Prerelease = 'beta5'
        }
    }

}
