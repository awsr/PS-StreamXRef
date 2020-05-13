
function Import-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InputObject,

        [Parameter()]
        [switch]$ReplaceData = $false
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

            Write-Error "API key missing from import." -Category ObjectNotFound

        }

        # Process UserIdCache
        if ($ConfigStaging.psobject.Properties.Name -contains "UserIdCache") {

            if ($ReplaceData -and $PSCmdlet.ShouldProcess("User ID lookup data", "Clear")) {

                Clear-XRefLookupData -UserIdCache

            }

            if ($PSCmdlet.ShouldProcess("User ID lookup data", "Import")) {

                $AddCount = 0
                $DupeCount = 0
                $BadDataCount = 0
    
                $ConfigStaging.UserIdCache.psobject.properties | ForEach-Object {
    
                    try {
    
                        $script:TwitchData.UserIdCache.Add( $_.Name, $_.Value )
                        $AddCount++
    
                    }
                    catch [System.ArgumentException] {
    
                        # This should be an error from there already being an existing entry with the same key
                        $DupeCount++
    
                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(UserIdCache) $($_.Exception.Message)"
                        $BadDataCount++
    
                    }

                }

                Write-Verbose "(UserIdCache) $AddCount entries added."
                Write-Verbose "(UserIdCache) $DupeCount duplicate entries skipped."

                if ($BadDataCount -gt 0) {

                    Write-Verbose "(UserIdCache) $BadDataCount entries could not be parsed."

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

                $AddCount = 0
                $DupeCount = 0
                $BadDataCount = 0
    
                $ConfigStaging.ClipInfoCache.psobject.properties | ForEach-Object {
    
                    try {

                        # Enforce casting to [int]
                        [int]$OffsetValue = $_.Value.Offset
                        [int]$VideoIDValue = $_.Value.VideoID

                        $script:TwitchData.ClipInfoCache.Add( $_.Name, @{ Offset = $OffsetValue; VideoID = $VideoIDValue } )
                        $AddCount++

                    }
                    catch [System.ArgumentException] {
    
                        # This should be an error from there already being an existing entry with the same key
                        $DupeCount++
    
                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(ClipInfoCache) $($_.Exception.Message)"
                        $BadDataCount++
    
                    }
    
                }

                Write-Verbose "(ClipInfoCache) $AddCount entries added."
                Write-Verbose "(ClipInfoCache) $DupeCount duplicate entries skipped."

                if ($BadDataCount -gt 0) {

                    Write-Verbose "(ClipInfoCache) $BadDataCount entries could not be parsed."

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

                $AddCount = 0
                $DupeCount = 0
                $BadDataCount = 0

                $ConfigStaging.VideoStartCache.psobject.properties | ForEach-Object {

                    try {
    
                        $ConvertedDateTime = $_.Value | ConvertTo-UtcDateTime
                        $script:TwitchData.VideoStartCache.Add( $_.Name, $ConvertedDateTime )
                        $AddCount++
                    }
                    catch [System.ArgumentException] {
    
                        # This should be an error from there already being an existing entry with the same key
                        $DupeCount++
    
                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(VideoStartCache) $($_.Exception.Message)"
                        $BadDataCount++
    
                    }

                }

                Write-Verbose "(VideoStartCache) $AddCount entries added."
                Write-Verbose "(VideoStartCache) $DupeCount duplicate entries skipped."

                if ($BadDataCount -gt 0) {

                    Write-Verbose "(VideoStartCache) $BadDataCount entries could not be parsed."

                }

            }

        }
        else {

            Write-Error "Video lookup data missing from input." -Category ObjectNotFound

        }

    }

}
