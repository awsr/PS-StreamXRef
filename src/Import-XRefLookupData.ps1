
function Import-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium", DefaultParameterSetName = "General")]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = "General")]
        [ValidateNotNullOrEmpty()]
        [string]$InputObject,

        [Parameter(ParameterSetName = "General")]
        [switch]$ReplaceData = $false,

        [Parameter(ParameterSetName = "General")]
        [switch]$PassThru = $false,

        [Parameter(Mandatory = $true, ParameterSetName = "ApiKey")]
        [string]$ApiKey
    )

    Begin {

        # Initialize cache to import to if missing
        if (-not (Test-Path Variable:Script:TwitchData)) {

            try {

                Write-Warning "Lookup data is missing. Reinitializing."
                
                Initialize-LookupCache -ErrorAction Stop

            }
            catch {

                # This also forces script to halt if the command isn't found,
                # indicating the module wasn't loaded correctly
                $PSCmdlet.ThrowTerminatingError($_)

            }

        }

    }

    Process {

        # Importing just the ApiKey
        if ($PSBoundParameters.ContainsKey("ApiKey")) {

            $script:TwitchData.ApiKey = $ApiKey
            return

        }

        # Remove surrounding whitespaces from input
        $InputObject = $InputObject.Trim()

        # Check if not a JSON string
        if ( -not ($InputObject.StartsWith('{') -and $InputObject.EndsWith('}'))) {

            Write-Verbose "Parsing input as file path"

            if (Test-Path $InputObject) {

                # Get content from file and use -Raw to keep together as a single string
                $InputObject = Get-Content $InputObject -Raw

            }
            else {

                throw "Input file not found or invalid data: $InputObject"

            }

        }
        else {

            Write-Verbose "Parsing input as JSON string"

        }

        $ConfigStaging = ConvertFrom-Json $InputObject -ErrorAction Stop

        # Store as a hashtable for ease of access within the function.
        $Counters = @{}
        "User", "Clip", "Video" | ForEach-Object {

            $tempobj = [pscustomobject]@{
                Name = $_
                Added = 0
                Duplicate = 0
                Error = 0
            }
            Add-Member -InputObject $tempobj -MemberType ScriptProperty -Name Total -Value {$this.Added + $this.Duplicate + $this.BadData}

            $Counters.Add($_, $tempobj)
        }

        # Process ApiKey
        if ($ConfigStaging.psobject.Properties.Name -contains "ApiKey") {

            if ($null, "" -contains $script:TwitchData.ApiKey) {

                # No pre-existing data, so no need for confirmation
                $script:TwitchData.ApiKey = $ConfigStaging.ApiKey

            }
            elseif ($ReplaceData -and $PSCmdlet.ShouldProcess("Api key", "Clear")) {

                # Perform ApiKey replacement within this block because
                # it is not a collection that can be added to
                $script:TwitchData.ApiKey = $ConfigStaging.ApiKey
                Write-Verbose "API key replaced."

            }
            elseif ($script:TwitchData.ApiKey -ine $ConfigStaging.ApiKey) {

                Write-Warning "New API key was provided but -ReplaceData was not specified"

            }

        }
        else {

            if ($null, "" -contains $script:TwitchData.ApiKey) {

                Write-Error "API key missing from input." -Category ObjectNotFound

            }
            else {

                # Not an error if one is already set
                Write-Warning "API key missing from input."

            }

        }

        # Process UserIdCache
        if ($ConfigStaging.psobject.Properties.Name -contains "UserIdCache") {

            if ($ReplaceData -and $PSCmdlet.ShouldProcess("User ID lookup data", "Clear")) {

                Clear-XRefLookupData -UserIdCache

            }

            if ($PSCmdlet.ShouldProcess("User ID lookup data", "Import")) {

                $ConfigStaging.UserIdCache.psobject.properties | ForEach-Object {
    
                    try {
    
                        $script:TwitchData.UserIdCache.Add( $_.Name, $_.Value )
                        $Counters.User.Added++
    
                    }
                    catch [System.ArgumentException] {
    
                        # This should be an error from there already being an existing entry with the same key
                        $Counters.User.Duplicate++
    
                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(UserIdCache) $($_.Exception.Message)"
                        $Counters.User.Error++
    
                    }

                }

                Write-Verbose "(UserIdCache) $($Counters.User.Added) entries added."
                Write-Verbose "(UserIdCache) $($Counters.User.Duplicate) duplicate entries skipped."

                if ($Counters.User.Error -gt 0) {

                    Write-Verbose "(UserIdCache) $($Counters.User.Error) entries could not be parsed."

                }

            }

        }
        else {

            Write-Error "User lookup data missing from input." -Category ObjectNotFound

        }

        # Process ClipInfoCache
        if ($ConfigStaging.psobject.Properties.Name -contains "ClipInfoCache") {

            if ($ReplaceData -and $PSCmdlet.ShouldProcess("Clip info lookup data", "Clear")) {

                Clear-XRefLookupData -ClipInfoCache

            }

            if ($PSCmdlet.ShouldProcess("Clip info lookup data", "Import")) {

                $ConfigStaging.ClipInfoCache.psobject.properties | ForEach-Object {
    
                    try {

                        # Enforce casting to [int]
                        [int]$OffsetValue = $_.Value.Offset
                        [int]$VideoIDValue = $_.Value.VideoID

                        $script:TwitchData.ClipInfoCache.Add( $_.Name, @{ Offset = $OffsetValue; VideoID = $VideoIDValue } )
                        $Counters.Clip.Added++

                    }
                    catch [System.ArgumentException] {
    
                        # This should be an error from there already being an existing entry with the same key
                        $Counters.Clip.Duplicate++
    
                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(ClipInfoCache) $($_.Exception.Message)"
                        $Counters.Clip.Error++
    
                    }
    
                }

                Write-Verbose "(ClipInfoCache) $($Counters.Clip.Added) entries added."
                Write-Verbose "(ClipInfoCache) $($Counters.Clip.Duplicate) duplicate entries skipped."

                if ($Counters.Clip.Error -gt 0) {

                    Write-Verbose "(ClipInfoCache) $($Counters.Clip.Error) entries could not be parsed."

                }

            }

        }
        else {

            Write-Warning "Clip lookup data missing from input." -Category ObjectNotFound

        }

        # Process VideoStartCache
        if ($ConfigStaging.psobject.Properties.Name -contains "VideoStartCache") {

            if ($ReplaceData -and $PSCmdlet.ShouldProcess("Video timestamp lookup data", "Clear")) {

                Clear-XRefLookupData -VideoStartCache

            }

            if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Import")) {

                $ConfigStaging.VideoStartCache.psobject.properties | ForEach-Object {

                    try {
    
                        $ConvertedDateTime = $_.Value | ConvertTo-UtcDateTime
                        $script:TwitchData.VideoStartCache.Add( $_.Name, $ConvertedDateTime )
                        $Counters.Video.Added++
                    }
                    catch [System.ArgumentException] {
    
                        # This should be an error from there already being an existing entry with the same key
                        $Counters.Video.Duplicate++
    
                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(VideoStartCache) $($_.Exception.Message)"
                        $Counters.Video.Error++
    
                    }

                }

                Write-Verbose "(VideoStartCache) $($Counters.Video.Added) entries added."
                Write-Verbose "(VideoStartCache) $($Counters.Video.Duplicate) duplicate entries skipped."

                if ($Counters.Video.Error -gt 0) {

                    Write-Verbose "(VideoStartCache) $($Counters.Video.Error) entries could not be parsed."

                }

            }

        }
        else {

            Write-Error "Video lookup data missing from input." -Category ObjectNotFound

        }

    }

    End {

        if ($PassThru) {

            # Return as an array for better display formatting
            return @($Counters.User, $Counters.Clip, $Counters.Video)

        }
    }

}
