Set-StrictMode -Version 3

# Add type data
Add-Type -Path "$PSScriptRoot/typedata/StreamXRefTypes.dll"

try {
    # Initialize cache (see comment at end of file for structure reference)
    $script:TwitchData = [StreamXRef.DataCache]::new()
}
catch {
    throw "Unable to initialize StreamXRef data object"
}

#region Internal shared helper functions ================

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

#region Load and setup commands ================

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

# Workaround for scoping issue with [ArgumentCompleter()] for Find-TwitchXRef
$TXRArgumentCompleter = {
    Param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    $script:TwitchData.UserInfoCache.Keys | Where-Object { $_ -like "$wordToComplete*" }
}
Register-ArgumentCompleter -CommandName Find-TwitchXRef -ParameterName XRef -ScriptBlock $TXRArgumentCompleter

$FunctionNames = $AllFunctions | ForEach-Object {
    # Use the name of the file to specify function(s) to be exported
    # Filter out potential ".Legacy" from name
    $_.Name.Split('.')[0]
}

New-Alias -Name txr -Value Find-TwitchXRef -ErrorAction Ignore

Export-ModuleMember -Alias "txr"
Export-ModuleMember -Function $FunctionNames

#endregion Load and setup commands -------------

#region Persistent data ========================

[Flags()] enum SXRPersistFormat {
    None = 0
    Compress = 1
    NoMapping = 2
}

$script:PersistCanUse = $false
$script:PersistEnabled = $false
$script:PersistId = 0
$script:PersistFormatting = [SXRPersistFormat]::None

try {
    # Get path inside try/catch in case of problems resolving the path
    $script:PersistPath = Join-Path ([System.Environment]::GetFolderPath("ApplicationData")) "StreamXRef/datacache.json"
    $script:PersistCanUse = $true
}
catch {
    $script:PersistCanUse = $false
}

<#
Initial check for persistence path override
 Technically, uninitialized $Env: variables still resolve to $null even in strict mode,
 but this way guards against that behavior changing in the future and causing issues with strict mode.
#>
if ((Test-Path Env:XRefPersistPath) -and $null -ne $Env:XRefPersistPath) {
    if ((Test-Path $Env:XRefPersistPath -IsValid) -and $Env:XRefPersistPath -like "*.json") {
        $script:PersistPath = $Env:XRefPersistPath
        $script:PersistCanUse = $true
    }
    else {
        Write-Error "XRefPersistPath environment variable must specify a .json file"
    }
}

# If the data file is found, automatically enable persistence
if ($PersistCanUse -and (Test-Path $PersistPath)) {
    Enable-XRefPersistence -Quiet
}

# Cleanup on unload
$ExecutionContext.SessionState.Module.OnRemove += {
    if ($PersistId -ne 0) {
        Unregister-Event -SubscriptionId $PersistId -ErrorAction SilentlyContinue
    }
}

#endregion Persistent data ---------------------

<#
Structure of StreamXRef.DataCache:

    [string]ApiKey:
        Value = [string] Client ID for API access

    [dictionary]UserInfoCache:
        Key   = [string] User/channel name
        Value = [int] User/channel ID number

    [dictionary]ClipInfoCache:
        Key   = [string] Clip slug name
        Value = [StreamXRef.ClipObject]@{
            Offset  = [int] Time offset in seconds
            VideoID = [int] Video ID number
            Created = [datetime] UTC date/time clip was created
            Mapping = [dictionary]@{
                Key   = [string] Username from a previous search
                Value = [string] URL returned from a previous search
            }
        }

    [dictionary]VideoInfoCache:
        Key   = [int] Video ID number
        Value = [datetime] Starting timestamp in UTC

(All dictionaries use case-insensitive keys)
#>
