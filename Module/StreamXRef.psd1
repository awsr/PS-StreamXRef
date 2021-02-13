@{

    RootModule = 'StreamXRef.psm1'

    Author = 'Alex Wiser'

    CompanyName = 'Alex Wiser'

    ModuleVersion = '3.3.0'

    GUID = '8c89ef10-5110-4406-a876-82b8eadf5bb2'

    Copyright = 'Copyright 2020 Alex Wiser. Licensed under MIT license.'

    Description = 'Given a Twitch clip or video timestamp URL, get a URL to the same moment from the cross-referenced video or channel.'

    PowerShellVersion = '5.1'

    DotNetFrameworkVersion = '4.7.1'

    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @('Find-TwitchXRef', 'Export-XRefData', 'Import-XRefData',
        'Clear-XRefData', 'Enable-XRefPersistence', 'Disable-XRefPersistence')

    AliasesToExport = @('txr')

    VariablesToExport = @('')

    # PowerShell Gallery: Define your module's metadata
    PrivateData = @{
        PSData = @{

            Tags = @('Stream', 'Twitch', 'Cross-Reference', 'Reference', 'Rest', 'API', 'Find', 'Search',
                'PSEdition_Desktop', 'PSEdition_Core', 'Windows', 'Linux', 'Mac')

            LicenseUri = 'https://github.com/awsr/PS-StreamXRef/blob/master/LICENSE'

            ProjectUri = 'https://github.com/awsr/PS-StreamXRef'

            IconUri = 'https://raw.githubusercontent.com/awsr/PS-StreamXRef/master/sxr.png'

            ReleaseNotes = @'
## 3.3.0

* Find: 2nd parameter name changed to `Target` (from `XRef`, which will still work).

## 3.2.0

* Find: Allow shorthand format for video sources ("v/...", "video/...").

## 3.1.1

* Persistence: Added options for compressing and excluding clip mapping.
* Persistence: Join 'datacache.json' to path if environment variable XRefPersistPath is not a *.json file.
* Import: Fixed counter only showing values from last file if pipelined multiple paths.

## 3.0.0

First version released as a full PowerShell Module.

* Renamed module to "StreamXRef" due to Twitch's limitations on project names
* Renamed `Get-TwitchXRef` to `Find-TwitchXRef`
* Changed alias from `gtxr` to `txr`
* Added data caching
* Added `Export-XRefData`, `Import-XRefData`, `Clear-XRefData`, `Enable-XRefPersistence`, and `Disable-XRefPersistence`
'@
        }
    }

}
