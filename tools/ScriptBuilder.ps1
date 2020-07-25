
<#PSScriptInfo

.VERSION 3.0.0

.GUID e8807dc8-6efa-4a7c-a205-7d14a794f374

.AUTHOR Alex Wiser

.COPYRIGHT 'Copyright 2020 Alex Wiser. Licensed under MIT license.'

#>

#Requires -Version 6

<#

.DESCRIPTION
 Custom build script for generating multiple scripts from a single source.

.PARAMETER File
 Input source file to read from.

.PARAMETER OutputRootPath
 Path to the main output directory.

.PARAMETER DefaultDirName
 Directory name for un-versioned scripts (sub-directory of $OutputRootPath).

.PARAMETER LabelDefinitions
 Output file mappings for labels.

#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateScript({ (Test-Path $_ -IsValid) -and ($_ -match '.*\.ps[dm]?1$') -and ($_ -notlike "*.Tests.ps1") })]
    [string]$File,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateScript({ Test-Path $_ -IsValid })]
    [string]$OutputRootPath,

    [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [ValidateScript({ Test-Path $_ -IsValid })]
    [string]$DefaultDirName,

    [Parameter(ValueFromRemainingArguments, ValueFromPipelineByPropertyName = $true)]
    [string[]]$LabelDefinitions
)

Set-StrictMode -Version Latest

#region Setup ##########################

# Create output directory if missing
if (-not (Test-Path $OutputRootPath)) {

    New-Item $OutputRootPath -ItemType Directory -ErrorAction Stop

}

# Read in the main source file
$Source = Get-Content $File -ErrorAction Stop | ForEach-Object {

    # Standardize blank lines
    if ([string]::IsNullOrWhiteSpace($_)) {

        Write-Output ([string]::Empty)

    }
    else {

        Write-Output $_

    }

}

$FileItem = Get-Item $File
$FileName = $FileItem.Name

$RelativeFilePath = [System.IO.Path]::GetRelativePath($PWD.Path, $File)

# Handle main module and manifest files
if ($File.EndsWith("psd1") -or $File.EndsWith("psm1")) {

    # Get new path for output file
    $NewPath = Join-Path $OutputRootPath $FileName

    $Source | Out-File $NewPath -Force -ErrorAction Stop

    Write-Verbose "$RelativeFilePath written to $NewPath"

    return

}

# If not flagged, write to default directory for scripts
if ($Source[0] -notlike "#.EnablePSCodeSets*") {

    Write-Verbose "EnablePSCodeSets flag not found"

    $DefaultDirPath = Join-Path $OutputRootPath $DefaultDirName

    # Check if directory doesn't exist
    if (-not (Test-Path $DefaultDirPath)) {

        # Create placeholder file and directories if missing
        New-Item -Path $DefaultDirPath -ItemType Directory -Force -ErrorAction Stop | Out-Null

    }

    $OutputFilePath = Join-Path $DefaultDirPath $FileName

    $Source | Out-File $OutputFilePath -Force -ErrorAction Stop

    Write-Verbose "$RelativeFilePath written to $OutputFilePath"

    return

}

$Mappings = @{}
$TempMaps = @{}
$ScriptDataSets = @{}
$OutputKeys = @()

# Allow for "#region...", "<#region...", and "<# #region..."
# Capture group saved to $Matches.Instruction
$RegionStartRegex = "^\s*(?:<|(?:<#\s*))?#region\s*@\{\s*(?<Instruction>.*=.*)\s*\}.*$"

Write-Verbose "Parsing $RelativeFilePath"

# Start with 1 since index 0 was the flag
$Offset = 1

# Skip blank lines after the initial flag
while ([string]::IsNullOrWhiteSpace($Source[$Offset])) {

    $Offset++

}

# Read label -> file mappings from remaining arguments
foreach ($Entry in $LabelDefinitions) {

    try {

        $TempMaps += ConvertFrom-StringData $Entry.Replace('\', '\\')

    }
    catch {

        Write-Error "Unable to parse mapping: $Entry"

    }

}

# Join target paths with main path unless full path is specified
try {

    $TempMaps.GetEnumerator() | ForEach-Object {

        if ([System.IO.Path]::IsPathFullyQualified($_.Value)) {

            $Mappings.Add($_.Key, $_.Value)

        }
        else {

            $Mappings.Add($_.Key, (Join-Path $OutputRootPath $_.Value))

        }

    }

}
catch [System.Management.Automation.MethodInvocationException] {

    $PSCmdlet.ThrowTerminatingError($_)

}

# Make sure we actually have something to do
if ($Mappings.Count -eq 0) {

    throw "No output files specified"

}

# Process mappings
$Mappings.GetEnumerator() | ForEach-Object {

    # Create empty array for holding lines and store in hashtable for lookup
    $ScriptDataSets.($_.Key) = @()

    # Save keys to another variable to avoid enumeration operation errors
    $OutputKeys += $_.Key

}

function ToAllOutputs {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$ToWrite
    )

    # Process for all outputs
    $OutputKeys | ForEach-Object {

        try {

            # Try adding line
            $script:ScriptDataSets.$_ += $ToWrite

        }
        catch {

            throw "Unable to add string to object.`n$_"

        }

    }

}

#endregion Setup =======================

# Begin main loop for processing source file
for ($Index = $Offset; $Index -lt $Source.Count; $Index++) {

    # Look for marker indicating an instruction to act upon
    if ($Source[$Index] -match $RegionStartRegex) {

        try {

            # Try processing the instruction
            $Instruction = ConvertFrom-StringData $Matches.Instruction

        }
        catch {

            # Could not read the instruction format
            Write-Error "Error parsing instruction: $($Matches.Instruction)"

            # Add the line to all outputs and continue
            $Source[$Index] | ToAllOutputs

            continue

        }

        # Check for "PSCodeSet" instruction and process if found
        if ($Instruction.ContainsKey("PSCodeSet")) {

            # Get parsed label
            $CodeSetLabel = $Instruction.PSCodeSet

            # If it's not known, write error and continue
            # Use "-notin" operator to prevent using reference equality since OutputKeys is a collection
            if ($CodeSetLabel -notin $script:OutputKeys) {

                Write-Error "Unknown output label: $CodeSetLabel"

                continue

            }
            else {

                # Take note of the line number before the instruction
                $SubLoopPrevIndex = $Index - 1

                # Skip adding the instruction comment to the output
                $Index++

                # Sub-loop for specific version until matching endregion marker is found
                # Matches "#> #endregion..." and "#endregion... #>"
                while ($Source[$Index] -notmatch "^\s*(?:#>\s*)?#endregion\s*@\{\s*(.*=\s*$CodeSetLabel)\s*\}.*(?:#>)?$") {

                    $script:ScriptDataSets.$CodeSetLabel += $Source[$Index]

                    $Index++

                }
                # End sub loop

                # Don't add current line with instruction to output

                # Check if lines before and after sub loop were both blank
                # First confirm that values are within bounds
                if (($SubLoopPrevIndex -ge 0) -and ($Index + 1 -lt $Source.Count)) {

                    # If blank or empty spaces
                    if ( (($Source[$SubLoopPrevIndex] -eq "") -or ($Source[$SubLoopPrevIndex] -match '^\s*$')) -and
                            (($Source[$Index + 1] -eq "") -or ($Source[$Index + 1] -match '^\s*$')) ) {

                            # If so, advance $Index by 1 to prevent excess whitespace in output files
                            $Index++

                    }

                }

                # Resume main loop
                continue

            }

        }
        else {

            # Using $Matches.Instruction is fine here because main instruction loop happened immediately before
            Write-Error "Unknown instruction: $($Matches.Instruction)"

            # Could be a false positive, so add it to all outputs
            $Source[$Index] | ToAllOutputs

            continue

        }

    }
    else {

        $Source[$Index] | ToAllOutputs

    }

}
# End main loop

# Write files

$Mappings.GetEnumerator() | ForEach-Object {

    # Make sure it's actually one that was processed
    if ($ScriptDataSets.ContainsKey($_.Key)) {

        # Check if path doesn't exist
        if (-not (Test-Path $_.Value)) {

            # Create placeholder file and directories if missing
            New-Item -Path $_.Value -ItemType File -Force -ErrorAction Stop | Out-Null

        }

        # Use mapping key to get corresponding script data and output to mapped location
        $ScriptDataSets[$_.Key] | Out-File $_.Value

        Write-Verbose "$RelativeFilePath parsed and written to $($_.Value)"

    }

}
