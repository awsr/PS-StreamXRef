#.ExternalHelp StreamXRef-help.xml
function Import-XRefData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low", DefaultParameterSetName = "General")]
    [OutputType([System.Void], [StreamXRef.ImportResults])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = "General")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "ApiKey")]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey,

        [Parameter(ParameterSetName = "General")]
        [switch]$PassThru,

        [Parameter()]
        [switch]$Quiet,

        [Parameter()]
        [switch]$Force
    )

    Begin {

        if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {

            $ConfirmPreference = "None"

        }

        $MappingWarning = $false
        $ConflictingData = $false

    }

    Process {

        if ($PSCmdlet.ParameterSetName -eq "General") {

            # Temporarily override ErrorActionPreference during required setup
            $EAPrefSetting = $ErrorActionPreference
            $ErrorActionPreference = "Stop"

            # This will now terminate the script if it fails
            $ImportStaging = Get-Content $Path -Raw | ConvertFrom-Json

            # Set up counters object
            $Counters = [StreamXRef.ImportResults]::new()
            $Counters.AddCounter("User")
            $Counters.AddCounter("Clip")
            $Counters.AddCounter("Video")

            # Restore ErrorActionPreference
            $ErrorActionPreference = $EAPrefSetting

        }

        # Process ApiKey (Check parameter set first since ConfigStaging won't exist in the ApiKey set)
        if ($PSCmdlet.ParameterSetName -eq "ApiKey" -or ($ImportStaging.psobject.Properties.Name -contains "ApiKey" -and -not [string]::IsNullOrWhiteSpace($ImportStaging.ApiKey))) {

            # Check if current API key is not set
            if ([string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey)) {
                # API key is not set

                # Specify "Import" since there's nothing being replaced
                if ($PSCmdlet.ShouldProcess("API key", "Import")) {

                    if ($PSCmdlet.ParameterSetName -eq "ApiKey") {

                        # Handling import via ApiKey parameter
                        $script:TwitchData.ApiKey = $ApiKey

                        if (-not $Quiet) {

                            Write-Host "API key imported."

                        }

                        return

                    }
                    else {

                        # Import API key from input object
                        $script:TwitchData.ApiKey = $ImportStaging.ApiKey

                        if (-not $Quiet) {

                            Write-Host "API key imported."

                        }

                    }

                }

            }
            else {
                # API key already exists

                if ($PSCmdlet.ParameterSetName -eq "ApiKey") {

                    # Get key via ApiKey parameter
                    $NewApiKey = $ApiKey

                }
                else {

                    # Get key from input object
                    $NewApiKey = $ConfigStaging.ApiKey

                }

                # Check if new key is different
                if ($script:TwitchData.ApiKey -ine $NewApiKey) {

                    # Specify "Replace" since previous value will be replaced
                    if ($PSCmdlet.ShouldProcess("API key", "Replace")) {

                        $script:TwitchData.ApiKey = $NewApiKey

                        if (-not $Quiet) {

                            Write-Host "API key replaced."

                        }

                        if ($PSCmdlet.ParameterSetName -eq "ApiKey") {

                            return

                        }

                    }

                }
                elseif (-not $Quiet) {

                    Write-Host "API key is unchanged."

                }

            }

        }
        elseif (-not $Quiet -and [string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey) -and $script:TwitchData.GetTotalCount() -eq 0) {

            # Lookup data cache is empty
            # Assume user is trying to restore from a full export
            Write-Warning "API key missing from input."

        }

        # Process UserInfoCache
        if ($ImportStaging.psobject.Properties.Name -contains "UserInfoCache" -and $ImportStaging.UserInfoCache.Count -gt 0) {

            # Check for confirm status here instead of for every single entry
            if ($PSCmdlet.ShouldProcess("User ID lookup data", "Import")) {

                $ImportStaging.UserInfoCache | ForEach-Object {

                    try {

                        # Check if entry already exists
                        if ($script:TwitchData.UserInfoCache.ContainsKey($_.name)) {

                            # If so, is the data the same?
                            if ($script:TwitchData.UserInfoCache[$_.name] -eq $_.id) {

                                # Already exists and can be skipped
                                $Counters.User.Skipped++

                            }
                            else {

                                if ($Force) {

                                    # Overwrite
                                    $script:TwitchData.UserInfoCache[$_.name] = $_.id
                                    $Counters.User.Imported++

                                }
                                else {

                                    $ConflictingData = $true
                                    $Counters.User.Error++

                                    if (-not $Quiet) {

                                        Write-Warning "Conflict for $($_.name): [new] $($_.id) -> [old] $($script:TwitchData.UserInfoCache[$_.name])"

                                    }

                                }

                            }

                        }
                        else {

                            # New data to add
                            $script:TwitchData.UserInfoCache[$_.name] = $_.id
                            $Counters.User.Imported++

                        }

                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                    [System.Management.Automation.PropertyNotFoundException] {

                        # Data formatting errors
                        Write-Error "(User Data) $($_.Exception.Message)" -Category InvalidData
                        $Counters.User.Error++

                    }
                    catch {

                        # Halt to prevent potential data corruption from unknown error
                        $PSCmdlet.ThrowTerminatingError($_)

                    }

                }

                Write-Verbose "(User Data) $($Counters.User.Imported) entries imported."
                if ($Counters.User.Skipped -gt 0) {
                    Write-Verbose "(User Data) $($Counters.User.Skipped) duplicate entries skipped."
                }
                if ($Counters.User.Error -gt 0) {
                    Write-Verbose "(User Data) $($Counters.User.Error) entries could not be parsed or conflicted with existing data."
                }

            }

        }

        # Process ClipInfoCache
        if ($ImportStaging.psobject.Properties.Name -contains "ClipInfoCache" -and $ImportStaging.ClipInfoCache.Count -gt 0) {

            if ($PSCmdlet.ShouldProcess("Clip info lookup data", "Import")) {

                $ImportStaging.ClipInfoCache | ForEach-Object {

                    try {

                        # Enforce casting to [int]
                        [int]$NewOffsetValue = $_.offset
                        [int]$NewVideoIDValue = $_.video

                        $ConvertedDateTime = $_.created | ConvertTo-UtcDateTime

                        if ($script:TwitchData.ClipInfoCache.ContainsKey($_.slug)) {

                            # Shorter variable for using in the "if" statements and warning message
                            $ExistingObject = $script:TwitchData.ClipInfoCache[$_.slug]

                            # Results mapping info is low priority and not checked here
                            if ($ExistingObject.Offset -eq $NewOffsetValue -and $ExistingObject.VideoID -eq $NewVideoIDValue -and $ExistingObject.Created -eq $ConvertedDateTime) {

                                $Counters.Clip.Skipped++

                            }
                            else {

                                if ($Force) {

                                    # Overwrite
                                    $script:TwitchData.ClipInfoCache[$_.slug] = [StreamXRef.ClipObject]@{ Offset = $NewOffsetValue; VideoID = $NewVideoIDValue; Created = $ConvertedDateTime; Mapping = @{} }
                                    $Counters.Clip.Imported++

                                }
                                else {

                                    $ConflictingData = $true
                                    $Counters.Clip.Error++

                                    if (-not $Quiet) {

                                        Write-Warning (
                                            "Conflict for $($_.slug):`n",
                                            "[new] $NewOffsetValue, $NewVideoIDValue, $ConvertedDateTime`n",
                                            "[old] $($ExistingObject.Offset), $($ExistingObject.VideoID), $($ExistingObject.Created)" -join ""
                                        )

                                    }

                                }

                            }

                        }
                        else {

                            # New data to add
                            $script:TwitchData.ClipInfoCache[$_.slug] = [StreamXRef.ClipObject]@{ Offset = $NewOffsetValue; VideoID = $NewVideoIDValue; Created = $ConvertedDateTime; Mapping = @{} }
                            $Counters.Clip.Imported++

                        }

                        # Try importing mapping subset
                        try {

                            foreach ($entry in $_.mapping) {

                                # Add to Mapping hashtable
                                $script:TwitchData.ClipInfoCache[$_.slug].Mapping[$entry.user] = $entry.result

                            }

                        }
                        catch {

                            $MappingWarning = $true

                        }

                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                    [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(Clip Data) $($_.Exception.Message)" -Category InvalidData
                        $Counters.Clip.Error++

                    }
                    catch {

                        # Halt to prevent potential data corruption from unknown error
                        $PSCmdlet.ThrowTerminatingError($_)

                    }

                }

                Write-Verbose "(Clip Data) $($Counters.Clip.Imported) entries imported."
                if ($Counters.Clip.Skipped -gt 0) {
                    Write-Verbose "(Clip Data) $($Counters.Clip.Skipped) duplicate entries skipped."
                }
                if ($Counters.Clip.Error -gt 0) {
                    Write-Verbose "(Clip Data) $($Counters.Clip.Error) entries could not be parsed or conflicted with existing data."
                }

            }

        }

        # Process VideoInfoCache
        if ($ImportStaging.psobject.Properties.Name -contains "VideoInfoCache" -and $ImportStaging.VideoInfoCache.Count -gt 0) {

            if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Import")) {

                $ImportStaging.VideoInfoCache | ForEach-Object {

                    try {

                        $ConvertedDateTime = $_.timestamp | ConvertTo-UtcDateTime

                        if ($script:TwitchData.VideoInfoCache.ContainsKey($_.video)) {

                            if ($script:TwitchData.VideoInfoCache[$_.video] -eq $ConvertedDateTime) {

                                $Counters.Video.Skipped++

                            }
                            else {

                                if ($Force) {

                                    # Overwrite
                                    $script:TwitchData.VideoInfoCache[$_.video] = $ConvertedDateTime
                                    $Counters.Video.Imported++

                                }
                                else {

                                    $ConflictingData = $true
                                    $Counters.Video.Error++

                                    if (-not $Quiet) {

                                        Write-Warning "For $($_.video): $ConvertedDateTime -> $($script:TwitchData.VideoInfoCache[$_.video])"

                                    }

                                }

                            }

                        }
                        else {

                            # New data to add
                            $script:TwitchData.VideoInfoCache[$_.video] = $ConvertedDateTime
                            $Counters.Video.Imported++

                        }

                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                    [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(Video Data) $($_.Exception.Message)" -Category InvalidData
                        $Counters.Video.Error++

                    }
                    catch {

                        # Halt to prevent potential data corruption from unknown error
                        $PSCmdlet.ThrowTerminatingError($_)

                    }

                }

                Write-Verbose "(Video Data) $($Counters.Video.Imported) entries imported."
                if ($Counters.Video.Skipped -gt 0) {
                    Write-Verbose "(Video Data) $($Counters.Video.Skipped) duplicate entries skipped."
                }
                if ($Counters.Video.Error -gt 0) {
                    Write-Verbose "(Video Data) $($Counters.Video.Error) entries could not be parsed or conflicted with existing data."
                }

            }

        }

    }

    End {

        if ($PSCmdlet.ParameterSetName -eq "General") {

            if ($ConflictingData) {
                Write-Error "Some data conflicts with existing values. Run with -Force to overwrite."
            }

            if ($MappingWarning) {
                Write-Warning "Some clip -> user mapping data could not be imported or was missing"
            }

            if (-not $Quiet) {

                $Counters.Values| Format-Table -AutoSize | Out-Host

            }

            if ($PassThru) {

                return $Counters

            }
            else {

                return

            }

        }

    }

}
