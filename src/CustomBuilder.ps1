
<#PSScriptInfo

.VERSION 1.0

.GUID e8807dc8-6efa-4a7c-a205-7d14a794f374

.AUTHOR Alex Wiser

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Custom build script for generating multiple scripts from a single source.

.PARAMETER SrcFile
 Input source file to read from.

.PARAMETER LabelInfo
 Output file mappings for labels.

#> 
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('.*\.ps1$')]
    [String]$File,

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$LabelInfo
)

$Mappings = @{}
$Outputs = @{}

$RegionStartRegex = '\s*#region\s*@\{\s*(.*=.*)\s*\}.*'

# Read label -> file mappings from remaining arguments
foreach ($Entry in $LabelInfo) {

    try {

        $Mappings += ConvertFrom-StringData $Entry.Replace('\', '\\')

    }
    catch {

        Write-Error "Unable to parse mapping: $Entry"

    }

}

# Make sure we actually have something to do
if ($Mappings.Count -eq 0) {

    throw "No output files specified"

}

# Process mappings
$Mappings.GetEnumerator() | ForEach-Object {

    # Create empty array for holding lines and store in hashtable for lookup
    $Outputs.($_.Key) = @()
}

# Save keys to another variable to avoid enumeration operation errors
$OutputKeys = $Outputs.Keys

# Read in the main source file
$Source = Get-Content $File

function ToAllOutputs {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$ToWrite
    )

    # Process for all outputs
    $OutputKeys | ForEach-Object {

        try {

            # Try adding line
            $Outputs.$_ += $ToWrite

        }
        catch {

            throw "Unable to add string to object.`n$_"

        }

    }

}

# Begin main loop for processing source file
foreach ($CurrentLine in $Source) {

    # Look for marker indicating an instruction to act upon
    if ($CurrentLine -match $RegionStartRegex) {

        try {

            # Try processing the instruction
            $Instruction = ConvertFrom-StringData $Matches[1]

        }
        catch {

            # Could not read the instruction format
            Write-Error "Error parsing instruction: $($Matches[1])"

            # Add the line to all outputs and continue
            $CurrentLine | ToAllOutputs

            continue

        }

        # Check for "PSCodeSet" instruction and process if found
        if ($Instruction.ContainsKey("PSCodeSet")) {

            $CodeVersion = $Instruction.PSCodeSet

            # If it's not known, write error and continue
            # Use "-notin" operator to prevent using reference equality since $OutputKeys is a collection
            if ($CodeVersion -notin $OutputKeys) {

                Write-Error "Unknown output label: $CodeVersion"

                continue

            }
            else {

                # Skip adding the instruction comment to the output
                $foreach.MoveNext()

                <#
                 Begin sub-loop for specific version processing.
                 Use $foreach.Current instead of $CurrentLine !!!
                #>

                # Continue to loop until matching endregion marker is found
                while ($foreach.Current -notmatch "\s*#endregion\s*@\{\s*(.*=\s*$CodeVersion)\s*\}.*)") {

                    $Outputs.$CodeVersion += $foreach.Current

                    $foreach.MoveNext()

                }
                # End sub loop

                # Don't add current line with instruction to output

                # Resume main loop
                continue

            }

        }
        else {

            # Using $Matches[1] is fine here because main instruction loop happened immediately before
            Write-Error "Unknown instruction: $($Matches[1])"

            # Could be a false positive, so add it to all outputs
            $CurrentLine | ToAllOutputs

            continue

        }

    }
    else {

        $CurrentLine | ToAllOutputs

    }

}
# End main loop

# Write files

$Mappings.GetEnumerator() | ForEach-Object {

    # Make sure it's actually one that was processed
    if ($Outputs.ContainsKey($_.Key)) {

        # Check if path doesn't exist
        if (-not (Test-Path $_.Value)) {

            # Create placeholder file and directories if missing
            New-Item -Path $_.Value -ItemType File -Force
    
        }

        $Outputs[$_.Key] | Out-File $_.Value

    }

}
