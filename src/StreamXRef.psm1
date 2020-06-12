Set-StrictMode -Version 3

# Add type data
try {

    # Try loading from assembly
    Add-Type -Path "$PSScriptRoot/typedata/StreamXRefTypes.dll"

}
catch {

    # As a fallback, compile from source and load into memory
    Add-Type -Path "$PSScriptRoot/typedata/StreamXRefTypes.cs" -ErrorAction Stop

}

#region Internal shared helper functions ================

function Initialize-LookupCache {
    [CmdletBinding()]
    Param()

    $script:TwitchData = [pscustomobject]@{

        # [string] Client ID for API access
        ApiKey         = $null

        # @{ [string] User/channel name; [int] User/channel ID number }
        UserInfoCache  = [System.Collections.Generic.Dictionary[string, int]]::new()

        # @{ [string] Clip slug name; @{ Offset = [int] Time offset in seconds; VideoID = [int] Video ID number; Created = [datetime] UTC date/time clip was created } }
        ClipInfoCache  = [System.Collections.Generic.Dictionary[string, pscustomobject]]::new()

        # @{ [int] Video ID number; [datetime] Starting timestamp in UTC }
        VideoInfoCache = [System.Collections.Generic.Dictionary[int, datetime]]::new()

    }

    $script:TwitchData | Add-Member -MemberType ScriptMethod -Name GetTotalCount -ErrorAction Stop -Value {

        $this.UserInfoCache.Count + $this.ClipInfoCache.Count + $this.VideoInfoCache.Count

    }

}

filter Get-LastUrlSegment {

    $Url = $_ -split "/" | Select-Object -Last 1
    return $Url -split "\?" | Select-Object -First 1

}

filter ConvertTo-UtcDateTime {

    if ($_ -is [datetime]) {

        if ($_.Kind -eq [System.DateTimeKind]::Utc) {

            # Already formatted correctly
            return $_

        }
        else {

            return $_.ToUniversalTime()

        }

    }
    elseif ($_ -is [string]) {

        return ([datetime]::Parse($_)).ToUniversalTime()

    }
    else {

        throw "Unable to convert to UTC: $_"

    }

}

#endregion Shared helper functions -------------

#region Initialize variables ===================

try {

    Initialize-LookupCache -ErrorAction Stop

}
catch {

    throw $_

}

#endregion Initialize variables ----------------

# If not running at least PowerShell 7.0, get the "PSLegacy" version of the functions
# Otherwise, load the "PSCurrent" version of the functions
if ($PSVersionTable.PSVersion.Major -lt 7) {

    $VersionedFunctions = @( Get-ChildItem $PSScriptRoot/PSLegacy/*.ps1 -ErrorAction SilentlyContinue )

}
else {

    $VersionedFunctions = @( Get-ChildItem $PSScriptRoot/PSCurrent/*.ps1 -ErrorAction SilentlyContinue )

}

$SharedFunctions = @( Get-ChildItem $PSScriptRoot/Shared/*.ps1 -ErrorAction SilentlyContinue )

$AllFunctions = $VersionedFunctions + $SharedFunctions

foreach ($FunctionFile in $AllFunctions) {

    try {

        # Dot source the file to load in function
        . $FunctionFile.FullName

    }
    catch {

        Write-Error "Failed to load $($FunctionFile.Directory.Name)/$($FunctionFile.BaseName): $_"

    }

}

$FunctionNames = $AllFunctions | ForEach-Object {

    # Use the name of the file to specify function(s) to be exported
    # Filter out potential ".Legacy" from name
    $_.Name.Split('.')[0]

}

New-Alias -Name txr -Value Find-TwitchXRef -ErrorAction Ignore

Export-ModuleMember -Alias "txr"
Export-ModuleMember -Function $FunctionNames
