#.ExternalHelp StreamXRef-help.xml
function Import-XRefData {
    [CmdletBinding(DefaultParameterSetName = "General")]
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
        [switch]$Persist,

        [Parameter()]
        [switch]$Quiet,

        [Parameter()]
        [switch]$Force
    )

    Begin {
        $MappingWarning = $false
        $ConflictingData = $false
        $NewKeyAdded = $false

        $IsGeneral = $PSCmdlet.ParameterSetName -eq "General"

        if ($IsGeneral) {
            try {
                # Set up counters object
                $Counters = [StreamXRef.ImportResults]::new()
                $Counters.AddCounter("User")
                $Counters.AddCounter("Clip")
                $Counters.AddCounter("Video")
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }

    Process {
        $SchemaVersion = 0

        if ($IsGeneral) {
            try {
                # Read file and convert from json
                $ImportStaging = Get-Content $Path -Raw | ConvertFrom-Json

                # Read metadata
                if ($ImportStaging.psobject.Properties.Name -contains "config") {
                    $SchemaVersion = $ImportStaging.config.schema
                }
            }
            catch {
                $PSCmdlet.WriteError($_)
                return
            }
        }

        # Process ApiKey (Check parameter set first since ImportStaging won't exist in the ApiKey set)
        if ($PSCmdlet.ParameterSetName -eq "ApiKey" -or ($ImportStaging.psobject.Properties.Name -contains "ApiKey" -and -not [string]::IsNullOrWhiteSpace($ImportStaging.ApiKey))) {
            # Get key from parameter or input object
            $script:TwitchData.ApiKey = ($PSCmdlet.ParameterSetName -eq "ApiKey") ? $ApiKey : $ImportStaging.ApiKey
            $NewKeyAdded = $true

            if (-not $Quiet) {
                Write-Host "API key imported."
            }

            if ($PSCmdlet.ParameterSetName -eq "ApiKey") {
                return
            }
        }
        elseif (-not $Quiet -and [string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey) -and $script:TwitchData.GetTotalCount() -eq 0) {
            # Lookup data cache is empty
            # Assume user is trying to restore from a full export
            Write-Warning "API key missing from input."
        }

        # Process UserInfoCache
        if ($ImportStaging.psobject.Properties.Name -contains "UserInfoCache" -and $ImportStaging.UserInfoCache.Count -gt 0) {
            $ImportStaging.UserInfoCache | ForEach-Object {
                try {
                    # Check if entry already exists
                    if ($script:TwitchData.UserInfoCache.ContainsKey($_.name)) {
                        # If so, is the data the same?
                        if ($script:TwitchData.UserInfoCache[$_.name] -eq $_.id) {
                            # Data is the same and can be skipped
                            $Counters.User.Skipped++
                        }
                        elseif ($Force) {
                            # Data is different and "Force" was specified, so overwrite the data
                            $script:TwitchData.UserInfoCache[$_.name] = $_.id
                            $Counters.User.Imported++
                        }
                        else {
                            # Data is different and "Force" was not specified
                            $ConflictingData = $true
                            $Counters.User.Error++

                            if (-not $Quiet) {
                                Write-Warning "Conflict for $($_.name): [new] $($_.id) -> [old] $($script:TwitchData.UserInfoCache[$_.name])"
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
                    # Halt on unknown error
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

        # Process ClipInfoCache
        if ($ImportStaging.psobject.Properties.Name -contains "ClipInfoCache" -and $ImportStaging.ClipInfoCache.Count -gt 0) {
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
                        elseif ($Force) {
                            $script:TwitchData.ClipInfoCache[$_.slug] = [StreamXRef.ClipObject]@{
                                Offset  = $NewOffsetValue
                                VideoID = $NewVideoIDValue
                                Created = $ConvertedDateTime
                                Mapping = @{}
                            }
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
                    else {
                        # New data to add
                        $script:TwitchData.ClipInfoCache[$_.slug] = [StreamXRef.ClipObject]@{
                            Offset  = $NewOffsetValue
                            VideoID = $NewVideoIDValue
                            Created = $ConvertedDateTime
                            Mapping = @{}
                        }
                        $Counters.Clip.Imported++
                    }

                    # Try importing mapping subset
                    try {
                        foreach ($entry in $_.mapping) {
                            # Add to Mapping
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
                    # Halt on unknown error
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

        # Process VideoInfoCache
        if ($ImportStaging.psobject.Properties.Name -contains "VideoInfoCache" -and $ImportStaging.VideoInfoCache.Count -gt 0) {
            $ImportStaging.VideoInfoCache | ForEach-Object {
                try {
                    $ConvertedDateTime = $_.timestamp | ConvertTo-UtcDateTime

                    if ($script:TwitchData.VideoInfoCache.ContainsKey($_.video)) {
                        if ($script:TwitchData.VideoInfoCache[$_.video] -eq $ConvertedDateTime) {
                            $Counters.Video.Skipped++
                        }
                        elseif ($Force) {
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
                    # Halt on unknown error
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

        if ($SchemaVersion -ge 1) {
            # Process optional persistence formatting data
            if ($ImportStaging.config.psobject.Properties.Name -contains "_persist") {
                $script:PersistFormatting = [SXRPersistFormat]$ImportStaging.config._persist
            }
        }
    }

    End {
        if ($Persist -and ($NewKeyAdded -or ($IsGeneral -and $Counters.AllImported -gt 0))) {
            if (Get-EventSubscriber -SourceIdentifier XRefNewDataAdded -Force -ErrorAction Ignore) {
                [void] (New-Event -SourceIdentifier XRefNewDataAdded -Sender "Import-XRefData")
            }
        }

        if ($IsGeneral) {
            if ($ConflictingData) {
                Write-Warning "Some lookup data conflicts with existing values. Run with -Force to overwrite."
            }
            if ($MappingWarning) {
                Write-Warning "Some Clip -> User mapping data could not be imported or was missing."
            }
            if (-not $Quiet) {
                $Counters.Values | Format-Table -AutoSize | Out-Host
            }
            if ($PassThru) {
                return $Counters
            }
        }
    }
}
