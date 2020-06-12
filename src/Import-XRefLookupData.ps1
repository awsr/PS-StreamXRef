#.ExternalHelp StreamXRef-help.xml
function Import-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium", DefaultParameterSetName = "General")]
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

        [Parameter(ParameterSetName = "General")]
        [switch]$Quiet,

        [Parameter()]
        [switch]$Force
    )

    Begin {

        if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {

            $ConfirmPreference = "None"

        }

        # Ensure requirements are loaded
        try {

            if ([StreamXRef.ImportResults] -is [type] -and -not (Test-Path Variable:Script:TwitchData)) {

                Initialize-LookupCache -ErrorAction Stop

            }

        }
        catch {

            # This also forces the function to halt if the command isn't found,
            # indicating the module wasn't loaded correctly
            $PSCmdlet.ThrowTerminatingError($_)

        }

        # Initial states for ShouldContinue
        $YesToAll = $false
        $NoToAll = $false

    }

    Process {

        if ($PSCmdlet.ParameterSetName -eq "General") {

            # Temporarily override ErrorActionPreference during required setup
            $EAPrefSetting = $ErrorActionPreference
            $ErrorActionPreference = "Stop"

            # This will now terminate the script if it fails
            $ConfigStaging = Get-Content $Path -Raw | ConvertFrom-Json

            # Set up counters object
            $Counters = [StreamXRef.ImportResults]::new()
            $Counters.Add("User", [StreamXRef.ImportCounter]::new("User"))
            $Counters.Add("Clip", [StreamXRef.ImportCounter]::new("Clip"))
            $Counters.Add("Video", [StreamXRef.ImportCounter]::new("Video"))

            # Restore ErrorActionPreference
            $ErrorActionPreference = $EAPrefSetting

        }

        # Process ApiKey (Check parameter set first since ConfigStaging won't exist in the ApiKey set)
        if ($PSCmdlet.ParameterSetName -eq "ApiKey" -or ($ConfigStaging.psobject.Properties.Name -contains "ApiKey" -and -not [string]::IsNullOrWhiteSpace($ConfigStaging.ApiKey))) {

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
                        $script:TwitchData.ApiKey = $ConfigStaging.ApiKey

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
                if ($script:TwitchData.ApiKey -ne $NewApiKey) {

                    # Specify "Replace" since previous value will be replaced
                    if ($PSCmdlet.ShouldProcess("API key", "Replace")) {

                        if ($PSCmdlet.ParameterSetName -eq "ApiKey") {

                            $script:TwitchData.ApiKey = $NewApiKey

                            if (-not $Quiet) {

                                Write-Host "API key replaced."

                            }

                            return

                        }
                        else {

                            $script:TwitchData.ApiKey = $NewApiKey

                            if (-not $Quiet) {

                                Write-Host "API key replaced."

                            }

                        }

                    }

                }
                elseif (-not $Quiet) {

                    Write-Host "API key is unchanged."

                }

            }

        }
        elseif ([string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey) -and $script:TwitchData.GetTotalCount() -eq 0) {

            # Lookup data cache is empty
            # Assume user is trying to restore from a full export
            Write-Error "API key missing from input."

        }
        else {

            # Already contains API key
            # User may have wanted to not keep the key in the JSON file, so not an error
            Write-Warning "API key missing from input."

        }

        # Process UserInfoCache
        if ($ConfigStaging.psobject.Properties.Name -contains "UserInfoCache" -and $ConfigStaging.UserInfoCache.Count -gt 0) {

            # Check for confirm status here instead of for every single entry
            if ($PSCmdlet.ShouldProcess("User ID lookup data", "Import")) {

                $ConfigStaging.UserInfoCache | ForEach-Object {

                    try {

                        # Check if entry already exists
                        if ($script:TwitchData.UserInfoCache.ContainsKey($_.name)) {

                            # If so, is the data the same?
                            if ($script:TwitchData.UserInfoCache[$_.name] -eq $_.id) {

                                # Already exists and can be skipped
                                $Counters.User.Skipped++

                            }
                            else {

                                Write-Warning "For $($_.name): $($_.id) -> $($script:TwitchData.UserInfoCache[$_.name])"

                                # Exists, but data is different
                                # Unless -Force is specified, ask how to continue becuase this should only occur due to data corruption
                                if ($Force -or $PSCmdlet.ShouldContinue("Input data entry differs from existing data", "Overwrite with new value?", [ref]$YesToAll, [ref]$NoToAll)) {

                                    # Overwrite
                                    $script:TwitchData.UserInfoCache[$_.name] = $_.id
                                    $Counters.User.Imported++

                                }
                                else {

                                    $Counters.User.Error++

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
        else {

            Write-Error "User lookup data missing from input."

        }

        # Process ClipInfoCache
        if ($ConfigStaging.psobject.Properties.Name -contains "ClipInfoCache" -and $ConfigStaging.ClipInfoCache.Count -gt 0) {

            if ($PSCmdlet.ShouldProcess("Clip info lookup data", "Import")) {

                $ConfigStaging.ClipInfoCache | ForEach-Object {

                    try {

                        # Enforce casting to [int]
                        [int]$NewOffsetValue = $_.offset
                        [int]$NewVideoIDValue = $_.video
                        $ConvertedDateTime = $_.created | ConvertTo-UtcDateTime

                        if ($script:TwitchData.ClipInfoCache.ContainsKey($_.slug)) {

                            # Shorter variable for using in the "if" statements and warning message
                            $ExistingObject = $script:TwitchData.ClipInfoCache[$_.slug]

                            if ($ExistingObject.Offset -eq $NewOffsetValue -and $ExistingObject.VideoID -eq $NewVideoIDValue -and $ExistingObject.Created -eq $ConvertedDateTime) {

                                $Counters.Clip.Skipped++

                            }
                            else {

                                Write-Warning (
                                    "For $($_.slug):`n",
                                    "[new] $NewOffsetValue, $NewVideoIDValue, $ConvertedDateTime`n",
                                    "[old] $($ExistingObject.Offset), $($ExistingObject.VideoID), $($ExistingObject.Created)" -join ""
                                )

                                if ($Force -or $PSCmdlet.ShouldContinue("Input data entry differs from existing data", "Overwrite with new value?", [ref]$YesToAll, [ref]$NoToAll)) {

                                    $script:TwitchData.ClipInfoCache[$_.slug] = [pscustomobject]@{ Offset = $NewOffsetValue; VideoID = $NewVideoIDValue; Created = $ConvertedDateTime }
                                    $Counters.Clip.Imported++

                                }
                                else {

                                    $Counters.Clip.Error++

                                }

                            }

                        }
                        else {

                            # New data to add
                            $script:TwitchData.ClipInfoCache[$_.slug] = [pscustomobject]@{ Offset = $NewOffsetValue; VideoID = $NewVideoIDValue; Created = $ConvertedDateTime }
                            $Counters.Clip.Imported++

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
        else {

            Write-Error "Clip lookup data missing from input."

        }

        # Process VideoInfoCache
        if ($ConfigStaging.psobject.Properties.Name -contains "VideoInfoCache" -and $ConfigStaging.VideoInfoCache.Count -gt 0) {

            if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Import")) {

                $ConfigStaging.VideoInfoCache | ForEach-Object {

                    try {

                        $ConvertedDateTime = $_.timestamp | ConvertTo-UtcDateTime

                        if ($script:TwitchData.VideoInfoCache.ContainsKey($_.video)) {

                            if ($script:TwitchData.VideoInfoCache[$_.video] -eq $ConvertedDateTime) {

                                $Counters.Video.Skipped++

                            }
                            else {

                                Write-Warning "For $($_.video): $ConvertedDateTime -> $($script:TwitchData.VideoInfoCache[$_.video])"

                                if ($Force -or $PSCmdlet.ShouldContinue("Input data entry differs from existing data", "Overwrite with new value?", [ref]$YesToAll, [ref]$NoToAll)) {

                                    $script:TwitchData.VideoInfoCache[$_.video] = $ConvertedDateTime
                                    $Counters.Video.Imported++

                                }
                                else {

                                    $Counters.Video.Error++

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
        else {

            Write-Error "Video lookup data missing from input."

        }

    }

    End {

        if ($PSCmdlet.ParameterSetName -eq "General") {

            if (-not $Quiet) {

                # Display import results
                $Counters.Values | Format-Table -AutoSize | Out-Host

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
