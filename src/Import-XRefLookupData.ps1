
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

            Initialize-LookupCache -ErrorAction Stop

        }

    }

    Process {

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
            elseif ($ReplaceData -and $PSCmdlet.ShouldProcess("Api key", "Replace")) {

                # Perform ApiKey replacement within this block because
                # it is not a collection that can be added to
                $script:TwitchData.ApiKey = $ConfigStaging.ApiKey
                Write-Verbose "API key replaced."

            }
            elseif ($script:TwitchData.ApiKey -ine $ConfigStaging.ApiKey) {

                Write-Warning "New API key was provided but -ReplaceData was not specified"

            }

        }

        # Process UserIdCache
        if ($ConfigStaging.psobject.Properties.Name -contains "UserIdCache") {

            if ($ReplaceData -and $PSCmdlet.ShouldProcess("User ID lookup data", "Replace")) {

                Clear-XRefLookupData -UserIdCache
                Write-Verbose "(UserIdCache) Data cleared."

            }

            $AddCount = 0
            $DupeCount = 0

            $ConfigStaging.UserIdCache.psobject.properties | ForEach-Object {

                try {

                    $script:TwitchData.UserIdCache.Add( $_.Name, $_.Value )
                    $AddCount++

                }
                catch [System.ArgumentException] {

                    # This should be an error from there already being an existing entry with the same key
                    $DupeCount++

                }
                catch [System.FormatException] {

                    Write-Error "(UserIdCache) Invalid data format -> $($_.Name), $($_.Value)"

                }

            }

            Write-Verbose "(UserIdCache) Added $AddCount entries."
            Write-Verbose "(UserIdCache) Skipped $DupeCount duplicate entries."

        }
        else {

            Write-Warning "User ID data missing"

        }

        # Process ClipInfoCache
        if ($ConfigStaging.psobject.Properties.Name -contains "ClipInfoCache") {

            if ($ReplaceData -and $PSCmdlet.ShouldProcess("Clip info lookup data", "Replace")) {

                Clear-XRefLookupData -ClipInfoCache
                Write-Verbose "(ClipInfoCache) Data cleared."

            }

            $AddCount = 0
            $DupeCount = 0

            $ConfigStaging.ClipInfoCache.psobject.properties | ForEach-Object {

                try {

                    $script:TwitchData.ClipInfoCache.Add( $_.Name, @{ Offset = $_.Value.Offset; VideoID = $_.Value.VideoID } )
                    $AddCount++
                }
                catch [System.ArgumentException] {

                    # This should be an error from there already being an existing entry with the same key
                    $DupeCount++

                }
                catch [System.FormatException] {

                    Write-Error "(ClipInfoCache) Invalid data format -> $($_.Name), @{ Offset = $($_.Value.Offset); VideoID = $($_.Value.VideoID) }"

                }

            }

            Write-Verbose "(ClipInfoCache) Added $AddCount entries."
            Write-Verbose "(ClipInfoCache) Skipped $DupeCount duplicate entries."

        }

        # Process VideoStartCache
        if ($ConfigStaging.psobject.Properties.Name -contains "VideoStartCache") {

            if ($ReplaceData -and $PSCmdlet.ShouldProcess("Video timestamp lookup data", "Replace")) {

                Clear-XRefLookupData -VideoStartCache
                Write-Verbose "(VideoStartCache) Data cleared."

            }

            $AddCount = 0
            $DupeCount = 0

            $ConfigStaging.VideoStartCache.psobject.properties | ForEach-Object {

                try {

                    $script:TwitchData.VideoStartCache.Add( $_.Name, ($_.Value | ConvertTo-UtcDatetime) )
                    $AddCount++
                }
                catch [System.ArgumentException] {

                    # This should be an error from there already being an existing entry with the same key
                    $DupeCount++

                }
                catch [System.FormatException] {

                    Write-Error "(VideoStartCache) Invalid data format -> $($_.Name), $($_.Value)"

                }

            }

            Write-Verbose "(VideoStartCache) Added $AddCount entries."
            Write-Verbose "(VideoStartCache) Skipped $DupeCount duplicate entries."

        }

    }

}
