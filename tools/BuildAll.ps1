
<#PSScriptInfo

.VERSION 1.0

.GUID 1b4f17b6-2f8c-4aa1-8135-5e143bb21e28

.AUTHOR Alex Wiser

.COPYRIGHT 'Copyright 2020 Alex Wiser. Licensed under MIT license.'

#>

#Requires -Version 7

<#

.DESCRIPTION
 Run ScriptBuilder for all PowerShell script files.

#>
[CmdletBinding()]
Param(
    [Parameter()]
    [switch]$ForDebug
)

$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Make sure it's actually the PS-StreamXRef directory
if ($ProjectRoot -inotlike "*PS-StreamXRef") {
    throw "Project root directory is incorrect"
}

$BuildParameters = [System.Collections.Generic.List[hashtable]]::new()

#region Config
$ScriptBuilder = Join-Path $ProjectRoot "tools/ScriptBuilder.ps1"

$OutPath = $ForDebug ? (Join-Path $ProjectRoot "debug/Module") : (Join-Path $ProjectRoot "Module")
$srcItems = Join-Path $ProjectRoot "src/*"
#endregion Config

$Files = Get-ChildItem $srcItems -Include "*.ps1", "*.psd1", "*.psm1"
$Files | ForEach-Object {
    $BuildParameters.Add(
        @{
            File             = $_.FullName
            OutputRootPath   = $OutPath
            DefaultDirName   = "Shared"
            ScriptToGlobal   = $ForDebug
            Verbose          = $true
            LabelDefinitions = @(
                "Current = PSCurrent/$($_.Name)",
                "Legacy = PSLegacy/$($_.BaseName).Legacy.ps1"
            )
        }
    )
}

try {
    $BuildParameters | ForEach-Object {
        # Call the ScriptBuilder script and use splatting to populate the parameters
        & $ScriptBuilder @_
    }
}
catch {
    throw $_
}

if ($ForDebug -and (Get-Command dotnet)) {
    $typedataPath = Join-Path $OutPath "typedata/StreamXRefTypes.dll"

    dotnet build -c Debug "$ProjectRoot/src/dotnet/StreamXRefTypes.csproj"

    if (-not (Test-Path $typedataPath)) {
        # Placeholder file
        New-Item $typedataPath -ItemType File
    }

    Copy-Item "$ProjectRoot/src/dotnet/bin/Debug/netstandard2.0/StreamXRefTypes.dll" $typedataPath
    Write-Verbose "Assembly copied to $typedataPath"
}
