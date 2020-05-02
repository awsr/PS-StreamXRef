Set-StrictMode -Version 3

# Initialize variables
$script:Twitch_API_ClientID = $null
$script:Twitch_API_UserIDCache = @{}

#region Shared helper function(s)
filter Get-IdFromUri {
    $Uri = $_ -split "/" | Select-Object -Last 1
    return $Uri -split "\?" | Select-Object -First 1
}
#endregion

# Dot source the "PSLegacy" version if not running at least PowerShell 7.0
# Otherwise, load the "PSCurrent" version of the function(s)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $FunctionRoot = Join-Path $PSScriptRoot "PSLegacy"
}
else {
    $FunctionRoot = Join-Path $PSScriptRoot "PSCurrent"
}

$AllFunctions = Get-ChildItem (Join-Path $FunctionRoot "*.ps1") -File

foreach ($File in $AllFunctions) {
    try {
        # Dot source the file to load in function
        . $File.FullName
    }
    catch {
        Write-Error "Failed to load $($File.BaseName): $_"
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
