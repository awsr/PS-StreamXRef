
function Import-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium", DefaultParameterSetName = "General")]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = "General")]
        [ValidateNotNullOrEmpty()]
        [string]$InputObject,

        [Parameter(ParameterSetName = "General")]
        [switch]$PassThru = $false,

        [Parameter(Mandatory = $true, ParameterSetName = "ApiKey")]
        [string]$ApiKey,

        [Parameter(ParameterSetName = "General")]
        [Parameter(ParameterSetName = "ApiKey")]
        [switch]$Force = $false

    )

    Begin {

        if ($Force -and -not ($PSBoundParameters.ContainsKey("Confirm") -and $Confirm)) {

            $ConfirmPreference = "none"

        }

        # Initial states for ShouldContinue
        $YesToAll = $false
        $NoToAll = $false

    }

    Process {

        if ($PSCmdlet.ParameterSetName -eq "General") {

            # Remove surrounding whitespaces from input
            $InputObject = $InputObject.Trim()

            # Check if not a JSON string
            if (-not ($InputObject.StartsWith('{') -and $InputObject.EndsWith('}'))) {

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

            # Store counters as a hashtable for ease of access within the function.
            $Counters = @{ }
            "User", "Clip", "Video" | ForEach-Object {

                $tempobj = [pscustomobject]@{
                    Name      = $_
                    Imported  = 0
                    Ignored = 0
                    Skipped   = 0
                    Error     = 0
                }
                Add-Member -InputObject $tempobj -MemberType ScriptProperty -Name Total -Value { $this.Imported + $this.Ignored + $this.Skipped + $this.Error }

                $Counters.Add($_, $tempobj)

            }

        }

        # Process ApiKey (Check parameter set first since ConfigStaging won't exist in the ApiKey set)
        if ($PSCmdlet.ParameterSetName -eq "ApiKey" -or $ConfigStaging.psobject.Properties.Name -contains "ApiKey") {

            # Check if current API key is not set
            if ($null, "" -contains $script:TwitchData.ApiKey) {

                # Specify "Import" since there's nothing being replaced
                if ($PSCmdlet.ShouldProcess("API key", "Import")) {

                    if ($PSCmdlet.ParameterSetName -eq "ApiKey") {

                        # Handling import via ApiKey parameter
                        $script:TwitchData.ApiKey = $ApiKey
                        return

                    }
                    else {

                        # Import API key from input object
                        $script:TwitchData.ApiKey = $ConfigStaging.ApiKey

                    }

                }

            }
            else {

                # Specify "Replace" since previous value will be replaced
                if ($PSCmdlet.ShouldProcess("API key", "Replace")) {

                    # Unless -Force is specified, ask how to continue
                    if ($Force -or $PSCmdlet.ShouldContinue("API key already exists", "Overwite with new key?")) {

                        if ($PSCmdlet.ParameterSetName -eq "ApiKey") {

                            # Handling import via ApiKey parameter
                            $script:TwitchData.ApiKey = $ApiKey
                            return

                        }
                        else {

                            # Import API key from input object
                            $script:TwitchData.ApiKey = $ConfigStaging.ApiKey

                        }

                    }

                }

            }

        }
        else {

            if ($null, "" -contains $script:TwitchData.ApiKey -and $script:TwitchData.GetTotalCount() -eq 0) {

                # Lookup data cache is empty
                # Assume user is trying to restore from a full export
                Write-Error "API key missing from input." -Category ObjectNotFound

            }
            else {

                Write-Warning "API key missing from input."

            }

        }

        # Process UserIdCache
        if ($ConfigStaging.psobject.Properties.Name -contains "UserIdCache") {

            # Check for confirm status here instead of for every single entry
            if ($PSCmdlet.ShouldProcess("User ID lookup data", "Import")) {

                $ConfigStaging.UserIdCache.psobject.properties | ForEach-Object {

                    try {

                        # Check if entry already exists
                        if ($script:TwitchData.UserIdCache.ContainsKey($_.Name)) {

                            # If so, is the data the same?
                            if ($script:TwitchData.UserIdCache[$_.Name] -eq $_.Value) {

                                # Already exists and can be ignored
                                $Counters.User.Ignored++

                            }
                            else {

                                Write-Warning "For $($_.Name): $($_.Value) -> $($script:TwitchData.UserIdCache[$_.Name])"

                                # Exists, but data is different
                                # Unless -Force is specified, ask how to continue becuase this should only occur due to data corruption
                                if ($Force -or $PSCmdlet.ShouldContinue("Input data entry differs from existing data", "Overwrite with new value?", [ref]$YesToAll, [ref]$NoToAll)) {

                                    # Overwrite
                                    $script:TwitchData.UserIdCache[$_.Name] = $_.Value
                                    $Counters.User.Imported++

                                }
                                else {

                                    # Skip
                                    $Counters.User.Skipped++

                                }

                            }

                        }
                        else {

                            # New data to add
                            $script:TwitchData.UserIdCache[$_.Name] = $_.Value
                            $Counters.User.Imported++

                        }

                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        # Data formatting errors
                        Write-Error "(User Data) $($_.Exception.Message)" -Category InvalidData
                        $Counters.User.Error++

                    }

                }

                Write-Verbose "(User Data) $($Counters.User.Imported) entries imported."
                if ($Counters.User.Ignored -gt 0) {
                    Write-Verbose "(User Data) $($Counters.User.Ignored) duplicate entries ignored."
                }
                if ($Counters.User.Skipped -gt 0) {
                    Write-Verbose "(User Data) $($Counters.User.Skipped) conflicting entries skipped"
                }
                if ($Counters.User.Error -gt 0) {
                    Write-Verbose "(User Data) $($Counters.User.Error) entries could not be parsed."
                }

            }

        }
        else {

            Write-Error "User lookup data missing from input." -Category ObjectNotFound

        }

        # Process ClipInfoCache
        if ($ConfigStaging.psobject.Properties.Name -contains "ClipInfoCache") {

            if ($PSCmdlet.ShouldProcess("Clip info lookup data", "Import")) {

                $ConfigStaging.ClipInfoCache.psobject.properties | ForEach-Object {

                    try {

                        # Enforce casting to [int]
                        [int]$NewOffsetValue = $_.Value.Offset
                        [int]$NewVideoIDValue = $_.Value.VideoID

                        if ($script:TwitchData.ClipInfoCache.ContainsKey($_.Name)) {

                            # Shorter variable for using in the "if" statements
                            $ExistingObject = $script:TwitchData.ClipInfoCache[$_.Name]

                            if ($ExistingObject.Offset -eq $NewOffsetValue -and $ExistingObject.VideoID -eq $NewVideoIDValue) {

                                $Counters.Clip.Ignored++

                            }
                            else {

                                Write-Warning "For $($_.Name): $NewOffsetValue, $NewVideoIDValue -> $($script:TwitchData.ClipInfoCache[$_.Name].Offset), $($script:TwitchData.ClipInfoCache[$_.Name].VideoID)"

                                if ($Force -or $PSCmdlet.ShouldContinue("Input data entry differs from existing data", "Overwrite with new value?", [ref]$YesToAll, [ref]$NoToAll)) {

                                    $script:TwitchData.ClipInfoCache[$_.Name] = [pscustomobject]@{ Offset = $NewOffsetValue; VideoID = $NewVideoIDValue }
                                    $Counters.Clip.Imported++

                                }
                                else {

                                    $Counters.Clip.Skipped++

                                }

                            }

                        }
                        else {

                            $script:TwitchData.ClipInfoCache[$_.Name] = [pscustomobject]@{ Offset = $NewOffsetValue; VideoID = $NewVideoIDValue }
                            $Counters.Clip.Imported++

                        }

                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(Clip Data) $($_.Exception.Message)" -Category InvalidData
                        $Counters.Clip.Error++

                    }

                }

                Write-Verbose "(Clip Data) $($Counters.Clip.Imported) entries imported."
                if ($Counters.Clip.Ignored -gt 0) {
                    Write-Verbose "(Clip Data) $($Counters.Clip.Ignored) duplicate entries ignored."
                }
                if ($Counters.Clip.Skipped -gt 0) {
                    Write-Verbose "(Clip Data) $($Counters.Clip.Skipped) conflicting entries skipped"
                }
                if ($Counters.Clip.Error -gt 0) {
                    Write-Verbose "(Clip Data) $($Counters.Clip.Error) entries could not be parsed."
                }

            }

        }
        else {

            Write-Warning "Clip lookup data missing from input." -Category ObjectNotFound

        }

        # Process VideoStartCache
        if ($ConfigStaging.psobject.Properties.Name -contains "VideoStartCache") {

            if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Import")) {

                $ConfigStaging.VideoStartCache.psobject.properties | ForEach-Object {

                    try {

                        $ConvertedDateTime = $_.Value | ConvertTo-UtcDateTime

                        if ($script:TwitchData.VideoStartCache.ContainsKey($_.Name)) {

                            if ($script:TwitchData.VideoStartCache[$_.Name] -eq $ConvertedDateTime) {

                                $Counters.Video.Ignored++

                            }
                            else {

                                Write-Warning "For $($_.Name): $ConvertedDateTime -> $($script:TwitchData.VideoStartCache[$_.Name])"

                                if ($Force -or $PSCmdlet.ShouldContinue("Input data entry differs from existing data", "Overwrite with new value?", [ref]$YesToAll, [ref]$NoToAll)) {

                                    $script:TwitchData.VideoStartCache[$_.Name] = $ConvertedDateTime
                                    $Counters.Video.Imported++

                                }
                                else {

                                    $Counters.Video.Skipped++

                                }

                            }

                        }
                        else {

                            $script:TwitchData.VideoStartCache[$_.Name] = $ConvertedDateTime
                            $Counters.Video.Imported++

                        }

                    }
                    catch [System.Management.Automation.PSInvalidCastException], [System.FormatException],
                        [System.Management.Automation.PropertyNotFoundException] {

                        Write-Error "(Video Data) $($_.Exception.Message)" -Category InvalidData
                        $Counters.Video.Error++

                    }

                }

                Write-Verbose "(Video Data) $($Counters.Video.Imported) entries imported."
                if ($Counters.Video.Ignored -gt 0) {
                    Write-Verbose "(Video Data) $($Counters.Video.Ignored) duplicate entries ignored."
                }
                if ($Counters.Video.Skipped -gt 0) {
                    Write-Verbose "(Video Data) $($Counters.Video.Skipped) conflicting entries skipped"
                }
                if ($Counters.Video.Error -gt 0) {
                    Write-Verbose "(Video Data) $($Counters.Video.Error) entries could not be parsed."
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
        else {

            Write-Verbose "$(@($Counters.User, $Counters.Clip, $Counters.Video) | Format-Table -AutoSize | Out-String)"

        }

    }

}
