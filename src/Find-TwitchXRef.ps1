#.EnablePSCodeSets
#.ExternalHelp StreamXRef-help.xml
function Find-TwitchXRef {
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ArgumentCompleter({
            Param(
                $commandName,
                $parameterName,
                $wordToComplete,
                $commandAst,
                $fakeBoundParameters
            )

            $script:TwitchData.UserInfoCache.Keys | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [ValidateNotNullOrEmpty()]
        [string]$XRef,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Count = 20,

        #region @{ PSCodeSet = Current }
        [Parameter()]
        [ValidateRange("NonNegative")]
        [int]$Offset = 0,
        #endregion @{ PSCodeSet = Current }
        <# #region @{ PSCodeSet = Legacy }
        [Parameter()]
        [ValidateScript({ $_ -ge 0 })]
        [int]$Offset = 0,
        #endregion @{ PSCodeSet = Legacy } #>

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [Alias("en")]
        [switch]$ExplicitNull
    )

    DynamicParam {
        $mandAttr = [System.Management.Automation.ParameterAttribute]::new()
        if ([string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey)) {
            $mandAttr.Mandatory = $true
        }
        else {
            $mandAttr.Mandatory = $false
        }
        $vnnoeAttr = [System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new()
        $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
        $attributeCollection.Add($mandAttr)
        $attributeCollection.Add($vnnoeAttr)

        $dynParam1 = [System.Management.Automation.RuntimeDefinedParameter]::new("ApiKey", [string], $attributeCollection)

        $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $paramDictionary.Add("ApiKey", $dynParam1)
        return $paramDictionary
    }

    Begin {

        if (-not (Test-Path Variable:Script:TwitchData)) {

            try {

                Write-Warning "Lookup data is missing. Reinitializing."

                Initialize-LookupCache -ErrorAction Stop

            }
            catch {

                # This also forces the function to halt if the command isn't found,
                # indicating the module wasn't loaded correctly
                $PSCmdlet.ThrowTerminatingError($_)

            }

        }

        $API = "https://api.twitch.tv/kraken"

        if ($PSBoundParameters.ContainsKey("ApiKey")) {
            $ClientID = $PSBoundParameters.ApiKey
            $script:TwitchData.ApiKey = $PSBoundParameters.ApiKey
        }
        else {
            $ClientID = $script:TwitchData.ApiKey
        }

        $v5Headers = @{
            "Client-ID" = $ClientID
            "Accept"    = "application/vnd.twitchtv.v5+json"
        }

        $NewDataAdded = $false

    }

    Process {

        <#  This trap is used for making all "404 Not Found" errors a non-terminating error
            because, for some reason, Twitch also uses that with some (but not all...) API
            endpoints to indicate that no results were found. #>
        #region @{ PSCodeSet = Current }
        trap [Microsoft.PowerShell.Commands.HttpResponseException] {
        #endregion @{ PSCodeSet = Current }
        <# #region @{ PSCodeSet = Legacy }
        trap [System.Net.WebException] {
        #endregion @{ PSCodeSet = Legacy } #>
            # API Responded with error status
            if ($_.Exception.Response.StatusCode -eq 404) {
                # Not found
                $PSCmdlet.WriteError($_)
                if ($ExplicitNull) {
                    return $null
                }
                else {
                    return
                }
            }
            else {
                # Other error status codes
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }

        $RestArgs = @{
            Method      = "Get"
            Headers     = $v5Headers
            ErrorAction = "Stop"
        }

        # Standardize input to lowercase
        $Source = $Source.ToLowerInvariant()
        $XRef = $XRef.ToLowerInvariant()

        #region Source Lookup ##########################

        if ($Source -imatch ".*twitch\.tv/videos/.+") {
            # Video URL provided

            $SourceParsedAsClip = $false

            # Check if missing timestamp
            if ($Source -inotmatch ".*twitch\.tv/videos/.+[?&]t=.+") {

                Write-Error "(Video) URL missing timestamp parameter" -ErrorId MissingTimestamp -Category InvalidArgument -CategoryTargetName Source -TargetObject $Source
                if ($ExplicitNull) {
                    return $null
                }
                else {
                    return
                }

            }

            #region Get offset from URL parameters
            [void]($Source -imatch ".*[?&]t=((?<Hours>\d+)h)?((?<Minutes>\d+)m)?((?<Seconds>\d+)s)?.*")

            #region @{ PSCodeSet = Current }
            $OffsetArgs = @{ }
            $OffsetArgs["Hours"] = $Matches.ContainsKey("Hours") ? $Matches.Hours : 0
            $OffsetArgs["Minutes"] = $Matches.ContainsKey("Minutes") ? $Matches.Minutes : 0
            $OffsetArgs["Seconds"] = $Matches.ContainsKey("Seconds") ? $Matches.Seconds : 0
            #endregion @{ PSCodeSet = Current }
            #region @{ PSCodeSet = Legacy}
            $OffsetArgs = @{
                Hours = 0
                Minutes = 0
                Seconds = 0
            }
            if ($Matches.ContainsKey("Hours")) {
                $OffsetArgs["Hours"] = $Matches.Hours
            }
            if ($Matches.ContainsKey("Minutes")) {
                $OffsetArgs["Minutes"] = $Matches.Minutes
            }
            if ($Matches.ContainsKey("Seconds")) {
                $OffsetArgs["Seconds"] = $Matches.Seconds
            }
            #endregion @{ PSCodeSet = Legacy }

            [timespan]$TimeOffset = New-TimeSpan @OffsetArgs
            #endregion

            [int]$VideoID = $Source | Get-LastUrlSegment

            $RestArgs["Uri"] = "$API/videos/$VideoID"

        }
        else {
            # Clip provided

            $SourceParsedAsClip = $true

            # Strip potential URL formatting
            $Slug = $Source | Get-LastUrlSegment

            $tmpFlagCached = $false

            if (-not $Force -and $script:TwitchData.ClipInfoCache.ContainsKey($Slug)) {
                # Found cached values to use

                try {

                    [timespan]$TimeOffset = New-TimeSpan -Seconds $script:TwitchData.ClipInfoCache[$Slug].Offset
                    [int]$VideoID = $script:TwitchData.ClipInfoCache[$Slug].VideoID

                    # Set REST arguments
                    $RestArgs["Uri"] = "$API/videos/$VideoID"

                    $tmpFlagCached = $true

                }
                catch {

                    # Suppress error output because the fallback will be to just look up the value again
                    [void]$_

                }

            }

            if (-not $tmpFlagCached) {
                # New uncached source ---- needs additional API call

                # Get information about clip
                $RestArgs["Uri"] = "$API/clips/$Slug"
                $ClipResponse = Invoke-RestMethod @RestArgs

                try {

                    # Verify that the source video was not removed
                    if ($null -eq $ClipResponse.vod) {

                        Write-Error "(Clip) Source video unavailable or deleted" -ErrorId VideoNotFound -Category ObjectNotFound -CategoryTargetName Source -TargetObject $Source -ErrorAction Stop

                    }

                    # Get offset from API response
                    [timespan]$TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset

                    # Get Video ID from API response
                    [int]$VideoID = $ClipResponse.vod.id

                    # Ensure timestamp was converted correctly
                    $ClipResponse.created_at = $ClipResponse.created_at | ConvertTo-UtcDateTime

                    # Add data to clip cache
                    $obj = [PSCustomObject]@{
                        Offset  = $ClipResponse.vod.offset
                        VideoID = $VideoID
                        Created = $ClipResponse.created_at
                    }
                    $script:TwitchData.ClipInfoCache[$Slug] = $obj
                    $NewDataAdded = $true

                }
                catch [Microsoft.PowerShell.Commands.WriteErrorException] {

                    # Write-Error forwarding and skip to next object in pipeline (if any)
                    $PSCmdlet.WriteError($_)
                    if ($ExplicitNull) {
                        return $null
                    }
                    else {
                        return
                    }

                }
                catch [System.Management.Automation.PropertyNotFoundException] {

                    Write-Host -BackgroundColor Black -ForegroundColor Red "Expected data missing from Twitch API response! Halting:`n"
                    $PSCmdlet.ThrowTerminatingError($_)

                }
                catch {

                    $PSCmdlet.ThrowTerminatingError($_)

                }

                # Set REST arguments
                $RestArgs["Uri"] = "$API/videos/$VideoID"

            }

        }

        # Set absolute timestamp of event

        # Check cache to see if this video is already known
        if (-not $Force -and $script:TwitchData.VideoInfoCache.ContainsKey($VideoID) -and $script:TwitchData.VideoInfoCache[$VideoID] -is [datetime]) {

            # Use start time from cache
            [datetime]$EventTimestamp = $script:TwitchData.VideoInfoCache[$VideoID] + $TimeOffset

        }
        else {

            # Get information about main video
            $VodResponse = Invoke-RestMethod @RestArgs

            try {

                # Check for incorrect video type
                if ($VodResponse.broadcast_type -ine "archive") {

                    # Set error message based on Source type
                    #region @{ PSCodeSet = Current }
                    $ErrSrc = $SourceParsedAsClip ? "(Clip) Referenced" : "(Video) Source"
                    #endregion @{ PSCodeSet = Current }
                    #region @{ PSCodeSet = Legacy }
                    if ($SourceParsedAsClip) {

                        $ErrSrc = "(Clip) Referenced"

                    }
                    else {

                        $ErrSrc = "(Video) Source"

                    }
                    #endregion @{ PSCodeSet = Legacy }

                    # Use "ErrorAction Stop" with specific catch block for forwarding
                    Write-Error "$ErrSrc video is not an archived broadcast" -ErrorId InvalidVideoType -Category InvalidOperation -ErrorAction Stop

                }

                # Ensure timestamp was converted correctly
                $VodResponse.recorded_at = $VodResponse.recorded_at | ConvertTo-UtcDateTime

                # Use start time from API response
                [datetime]$EventTimestamp = $VodResponse.recorded_at + $TimeOffset

                # Add data to Vod cache
                $script:TwitchData.VideoInfoCache[$VideoID] = $VodResponse.recorded_at
                $NewDataAdded = $true

            }
            catch [Microsoft.PowerShell.Commands.WriteErrorException] {

                # Write-Error forwarding and skip to next object in pipeline (if any)
                $PSCmdlet.WriteError($_)
                if ($ExplicitNull) {
                    return $null
                }
                else {
                    return
                }

            }
            catch [System.Management.Automation.PropertyNotFoundException] {

                Write-Host -BackgroundColor Black -ForegroundColor Red "Expected data missing from Twitch API response! Halting:`n"
                $PSCmdlet.ThrowTerminatingError($_)

            }
            catch {

                $PSCmdlet.ThrowTerminatingError($_)

            }

        }

        #endregion Source Lookup =======================

        #region XRef Lookup ############################

        if ($XRef -imatch ".*twitch\.tv/videos/.+") {
            # Using VOD link

            [int]$XRefID = $XRef | Get-LastUrlSegment
            $RestArgs["Uri"] = "$API/videos/$XRefID"

            $Multi = $false

        }
        else {
            # Using username/channel

            # Strip potential URL formatting
            $XRef = $XRef | Get-LastUrlSegment

            # Check ID cache for user
            if (-not $Force -and $script:TwitchData.UserInfoCache.ContainsKey($XRef) -and $script:TwitchData.UserInfoCache[$XRef] -is [int]) {

                # Get cached ID number
                [int]$UserIdNum = $script:TwitchData.UserInfoCache[$XRef]

            }
            else {

                # Get ID number for username using API
                $RestArgs["Uri"] = "$API/users"
                $RestArgs["Body"] = @{
                    "login" = $XRef
                }

                $UserLookup = Invoke-RestMethod @RestArgs

                try {

                    # Unlike other API requests, this doesn't return a 404 error if not found
                    if ($UserLookup._total -eq 0) {

                        Write-Error "(XRef Username) `"$XRef`" not found" -ErrorId UserNotFound -Category ObjectNotFound -CategoryTargetName XRef -TargetObject $XRef -ErrorAction Stop

                    }

                    [int]$UserIdNum = $UserLookup.users[0]._id

                    # Save ID number in cache hashtable
                    $script:TwitchData.UserInfoCache[$XRef] = $UserIdNum
                    $NewDataAdded = $true

                }
                catch [Microsoft.PowerShell.Commands.WriteErrorException] {

                    # Write-Error forwarding and skip to next object in pipeline (if any)
                    $PSCmdlet.WriteError($_)
                    if ($ExplicitNull) {
                        return $null
                    }
                    else {
                        return
                    }

                }
                catch [System.Management.Automation.PropertyNotFoundException] {

                    Write-Host -BackgroundColor Black -ForegroundColor Red "Expected data missing from Twitch API response! Halting:`n"
                    $PSCmdlet.ThrowTerminatingError($_)

                }
                catch {

                    $PSCmdlet.ThrowTerminatingError($_)

                }

            }

            # Set args using ID number
            $RestArgs["Uri"] = "$API/channels/$UserIdNum/videos"
            $RestArgs["Body"] = @{
                "broadcast_type" = "archive"
                "sort"           = "time"
                "limit"          = $Count
                "offset"         = $Offset
            }

            $Multi = $true

        }

        $XRefResponse = Invoke-RestMethod @RestArgs

        try {

            # Check for incorrect video type if XRef is a video URL ($Multi will be $false)
            if (-not $Multi -and $XRefResponse.broadcast_type -ine "archive") {

                Write-Error "(XRef Video) Video is not an archived broadcast" -ErrorId InvalidVideoType -Category InvalidOperation -CategoryTargetName XRef -TargetObject $XRef -ErrorAction Stop

            }

            #region @{ PSCodeSet = Current }
            $XRefSet = $Multi ? $XRefResponse.videos : $XRefResponse
            #endregion @{ PSCodeSet = Current }
            #region @{ PSCodeSet = Legacy }
            if ($Multi) {
                $XRefSet = $XRefResponse.videos
            }
            else {
                $XRefSet = $XRefResponse
            }
            #endregion @{ PSCodeSet = Legacy }

            if ($XRefSet -is [array]) {

                for ($i = 0; $i -lt $XRefSet.length; $i++) {
                    $XRefSet[$i].recorded_at = $XRefSet[$i].recorded_at | ConvertTo-UtcDateTime
                }

            }
            else {

                $XRefSet.recorded_at = $XRefSet.recorded_at | ConvertTo-UtcDateTime

            }

        }
        catch [Microsoft.PowerShell.Commands.WriteErrorException] {

            # Write-Error forwarding and skip to next object in pipeline (if any)
            $PSCmdlet.WriteError($_)
            if ($ExplicitNull) {
                return $null
            }
            else {
                return
            }

        }
        catch [System.Management.Automation.PropertyNotFoundException] {

            Write-Host -BackgroundColor Black -ForegroundColor Red "Expected data missing from Twitch API response! Halting:`n"
            $PSCmdlet.ThrowTerminatingError($_)

        }
        catch {

            $PSCmdlet.ThrowTerminatingError($_)

        }

        #endregion XRef Lookup =========================

        # Look for first video that starts before the timestamp

        try {

            $VideoToCompare = $null
            $VideoToCompare = $XRefSet | Where-Object { $_.recorded_at -lt $EventTimestamp } | Select-Object -First 1

            if ($null -eq $VideoToCompare) {

                Write-Error "Event occurs before search range" -ErrorId EventNotInRange -Category ObjectNotFound -CategoryTargetName EventTimestamp -TargetObject $Source -ErrorAction Stop

            }
            elseif ($EventTimestamp -gt $VideoToCompare.recorded_at.AddSeconds($VideoToCompare.length)) {

                # Event timestamp is after the end of stream
                Write-Error "Event not found during stream" -ErrorId EventNotFound -Category ObjectNotFound -CategoryTargetName EventTimestamp -TargetObject $Source -ErrorAction Stop

            }
            else {

                $NewOffset = $EventTimestamp - $VideoToCompare.recorded_at
                return "$($VideoToCompare.url)?t=$($NewOffset.Hours)h$($NewOffset.Minutes)m$($NewOffset.Seconds)s"

            }

        }
        catch [Microsoft.PowerShell.Commands.WriteErrorException] {

            # Write-Error forwarding and skip to next object in pipeline (if any)
            $PSCmdlet.WriteError($_)
            if ($ExplicitNull) {
                return $null
            }
            else {
                return
            }

        }
        catch [System.Management.Automation.PropertyNotFoundException] {

            Write-Host -BackgroundColor Black -ForegroundColor Red "Expected data missing from Twitch API response! Halting:`n"
            $PSCmdlet.ThrowTerminatingError($_)

        }
        catch {

            $PSCmdlet.ThrowTerminatingError($_)

        }

    }

    End {

        if ((Get-EventSubscriber -SourceIdentifier XRefNewDataAdded -Force -ErrorAction Ignore) -and $NewDataAdded) {

            New-Event -SourceIdentifier XRefNewDataAdded -Sender "StreamXRef"

        }

    }

}
