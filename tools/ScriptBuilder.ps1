Set-StrictMode -Version Latest
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

.PARAMETER File
 Input source file to read from.

.PARAMETER LabelDefinitions
 Output file mappings for labels.

.PARAMETER SharedPath
 Output path for shared files that skip processing.

#> 
function Build-Scripts {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ (Test-Path $_ -IsValid) -and ($_ -match '.*\.ps1$') })]
        [string]$File,
    
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$LabelDefinitions,
    
        [Parameter()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]$SharedPath
    )
    
    #region Pre-setup ######################
    
    # Read in the main source file
    $Source = Get-Content $File -ErrorAction Stop
    
    Write-Verbose "Parsing $File"
    
    # If not flagged, copy directly to output directories
    if ($Source[0] -notlike "#.EnablePSCodeSets") {
    
        # Make sure a path was given for shared files
        if ($PSBoundParameters.ContainsKey("SharedPath")) {
    
            # Check if path doesn't exist
            if (-not (Test-Path $SharedPath)) {
    
                # Create placeholder file and directories if missing
                New-Item -Path $SharedPath -ItemType File -Force -ErrorAction Stop | Out-Null
    
            }
    
            Copy-Item $File $SharedPath -Force
    
            Write-Verbose "$(Split-Path $File -Leaf) copied to $SharedPath"
    
            return
    
        }
        else {
    
            throw "No output path given for shared file $File"
    
        }
    
    }
    else {
    
        # Skip blank lines after the initial flag
        
        # Start with 1 since index 0 was the flag
        $script:Offset = 1
    
        #Only skip lines that are actually empty so that whitespaces can keep line padding if desired
        while ($Source[$script:Offset] -eq "") {
    
            $script:Offset++
    
        }
    
    }
    
    #endregion Pre-setup ===================
    
    #region Setup ##########################
    
    $Mappings = @{}
    $script:ScriptDataSets = @{}
    [string[]]$script:OutputKeys = @()
    
    # Allow for "#region...", "<#region...", and "<# #region..."
    $RegionStartRegex = "^\s*(?:<|(?:<#\s*))?#region\s*@\{\s*(?<Instruction>.*=.*)\s*\}.*$"
    
    # Read label -> file mappings from remaining arguments
    foreach ($Entry in $LabelDefinitions) {
    
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
        $script:ScriptDataSets.($_.Key) = @()
    
        # Save keys to another variable to avoid enumeration operation errors
        $script:OutputKeys += $_.Key
    
    }
    
    function ToAllOutputs {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [AllowEmptyString()]
            [string]$ToWrite
        )
    
        # Process for all outputs
        $script:OutputKeys | ForEach-Object {
    
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
    for ($Index = $script:Offset; $Index -lt $Source.Count; $Index++) {
    
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
        if ($script:ScriptDataSets.ContainsKey($_.Key)) {
    
            # Check if path doesn't exist
            if (-not (Test-Path $_.Value)) {
    
                # Create placeholder file and directories if missing
                New-Item -Path $_.Value -ItemType File -Force -ErrorAction Stop
        
            }
    
            # Use mapping key to get corresponding script data and output to mapped location
            $script:ScriptDataSets[$_.Key] | Out-File $_.Value
    
            Write-Verbose "$(Split-Path $File -Leaf) parsed and written to $($_.Value)"
    
        }
    
    }
    
}

Build-Scripts @args
