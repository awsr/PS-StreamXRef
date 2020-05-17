@{

    RootModule = 'Get-TwitchXRef.psm1'

    Author = 'Alex Wiser'

    CompanyName = 'Unknown'

    ModuleVersion = '2.9.9'

    GUID = '8c89ef10-5110-4406-a876-82b8eadf5bb2'

    Copyright = 'Copyright 2020 Alex Wiser. Licensed under MIT license.'

    Description = 'Given a Twitch clip or video timestamp URL, get a URL to the same moment from the cross-referenced video or channel.'

    PowerShellVersion = '5.1'

    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @('Get-TwitchXRef', 'Export-XRefLookupData', 'Import-XRefLookupData', 'Clear-XRefLookupData')

    AliasesToExport = @('gtxr')

    VariablesToExport = @('')

    # PowerShell Gallery: Define your module's metadata
    PrivateData = @{
        PSData = @{

            Tags = @('Twitch', 'Stream', 'Cross-Reference', 'Reference', 'Rest', 'API', 'Find', 'Search',
                'PSEdition_Desktop', 'PSEdition_Core', 'Windows', 'Linux', 'Mac')

            LicenseUri = 'https://github.com/awsr/Get-TwitchXRef/blob/master/LICENSE'

            ProjectUri = 'https://github.com/awsr/Get-TwitchXRef'

            IconUri = ''

            ReleaseNotes = @'
## 3.0.0

First version released as a full PowerShell Module.

* Added `Export-XRefLookupData`, `Import-XRefLookupData`, and `Clear-XRefLookupData`
'@
        }
    }

}