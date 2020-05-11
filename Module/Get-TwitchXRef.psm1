Set-StrictMode -Version 3

#region Internal shared helper functions ================

function Initialize-LookupCache {
    [CmdletBinding()]
    Param()

    $script:TwitchData = [pscustomobject]@{

        # [string] Client ID for API access
        ApiKey = $null

        # @{ [string] User/channel name; [int] User/channel ID number }
        UserIdCache = [System.Collections.Generic.Dictionary[string, int]]::new()

        # @{ [string] Clip slug name; @( [int] Time offset in seconds; [int] Video ID number ) }
        ClipInfoCache = [System.Collections.Generic.Dictionary[string, pscustomobject]]::new()

        # @{ [int] Video ID number; [datetime] Starting timestamp in UTC }
        VideoStartCache = [System.Collections.Generic.Dictionary[int, datetime]]::new()

    }

}

filter Get-LastUrlSegment {
    $Url = $_ -split "/" | Select-Object -Last 1
    return $Url -split "\?" | Select-Object -First 1
}

filter ConvertTo-UtcDateTime {
    if (($_ -is [datetime]) -and ($_.Kind -eq [System.DateTimeKind]::Utc)) {
        # Already formatted correctly
        return $_
    }
    elseif ($_ -is [datetime]) {
        return $_.ToUniversalTime()
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

Initialize-LookupCache

#endregion Initialize variables ----------------

# If not running at least PowerShell 7.0, get the "PSLegacy" version of the functions
# Otherwise, load the "PSCurrent" version of the functions
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $VersionedFunctions = @( Get-ChildItem $PSScriptRoot/PSLegacy/*.ps1 -ErrorAction SilentlyContinue )
}
else {
    $VersionedFunctions = @( Get-ChildItem $PSScriptRoot/PSCurrent/*.ps1 -ErrorAction SilentlyContinue)
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

Set-Alias -Name gtxr -Value Get-TwitchXRef

Export-ModuleMember -Alias "gtxr"
Export-ModuleMember -Function $FunctionNames
