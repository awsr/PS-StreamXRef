#.ExternalHelp StreamXRef-help.xml
function Find-TwitchXRef {
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias("XRef")]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Count = 20,

        [Parameter()]
        [ValidateRange("NonNegative")]
        [int]$Offset = 0,

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
        $API = "https://api.twitch.tv/kraken"
        $NewDataAdded = $false

        $VideoPattern = "(?:twitch\.tv/|^)v(?:ideos?)?/"

        if ($PSBoundParameters.ContainsKey("ApiKey")) {
            $ClientID = $PSBoundParameters.ApiKey

            if ($script:TwitchData.ApiKey -ine $PSBoundParameters.ApiKey) {
                $NewDataAdded = $true
            }

            $script:TwitchData.ApiKey = $PSBoundParameters.ApiKey
        }
        else {
            $ClientID = $script:TwitchData.ApiKey
        }

        $v5Headers = @{
            "Client-ID" = $ClientID
            "Accept"    = "application/vnd.twitchtv.v5+json"
        }

        # Temporary list for suppressing additional API calls when the username isn't found while processing a list/array of inputs
        $NotFoundList = [System.Collections.Generic.List[string]]::new()
    }

    Process {
        <#  This trap is used for making only "404 Not Found" errors a non-terminating error
            because, for some reason, Twitch also uses that with some (but not all...) API
            endpoints to indicate that no results were found. #>
        trap [Microsoft.PowerShell.Commands.HttpResponseException] {
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

        # Initial basic sorting
        $SourceIsVideo = $Source -imatch $VideoPattern ? $true : $false
        $TargetIsVideo = $Target -imatch $VideoPattern ? $true : $false

        #region Source Lookup ##########################

        if ($SourceIsVideo) {
            # Video URL provided

            # Get offset from URL parameters or return if no match
            if ($Source -inotmatch "[?&]t=((?<Hours>\d+)h)?((?<Minutes>\d+)m)?((?<Seconds>\d+)s)?") {
                Write-Error "(Video) URL missing timestamp parameter." -ErrorId MissingTimestamp -Category InvalidArgument -CategoryTargetName Source -TargetObject $Source
                if ($ExplicitNull) {
                    return $null
                }
                else {
                    return
                }
            }

            $OffsetArgs = @{ }
            $OffsetArgs["Hours"] = $Matches.ContainsKey("Hours") ? $Matches.Hours : 0
            $OffsetArgs["Minutes"] = $Matches.ContainsKey("Minutes") ? $Matches.Minutes : 0
            $OffsetArgs["Seconds"] = $Matches.ContainsKey("Seconds") ? $Matches.Seconds : 0

            $TimeOffset = New-TimeSpan @OffsetArgs

            # Assuming that Twitch will switch to 64-bit integers once they run out of room with 32-bit
            [Int64]$VideoID = $Source | Get-LastUrlSegment

            $RestArgs["Uri"] = "$API/videos/$VideoID"
        }
        else {
            # Clip provided

            # Strip potential URL formatting
            $Slug = $Source | Get-LastUrlSegment

            if (-not $Force -and $script:TwitchData.ClipInfoCache.ContainsKey($Slug)) {
                # Found cached values to use

                if (-not $TargetIsVideo -and $script:TwitchData.ClipInfoCache[$Slug].Mapping.ContainsKey($Target)) {
                    # Quick return path using cached data
                    return $script:TwitchData.ClipInfoCache[$Slug].Mapping[$Target]
                }
                else {
                    $TimeOffset = New-TimeSpan -Seconds $script:TwitchData.ClipInfoCache[$Slug].Offset
                    $VideoID = $script:TwitchData.ClipInfoCache[$Slug].VideoID
                    # Set REST arguments
                    $RestArgs["Uri"] = "$API/videos/$VideoID"
                }
            }
            else {
                # New uncached source ---- needs additional API call

                # Get information about clip
                $RestArgs["Uri"] = "$API/clips/$Slug"
                $ClipResponse = Invoke-RestMethod @RestArgs

                try {
                    # Verify that the source video was not removed
                    if ($null -eq $ClipResponse.vod) {
                        Write-Error "(Clip) Source video unavailable or deleted." -ErrorId VideoNotFound -Category ObjectNotFound -CategoryTargetName Source -TargetObject $Source -ErrorAction Stop
                    }

                    # Get offset from API response
                    $TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset

                    # Get Video ID from API response
                    [Int64]$VideoID = $ClipResponse.vod.id

                    # Add username to cache
                    if (-not $script:TwitchData.UserInfoCache.ContainsKey($ClipResponse.broadcaster.name)) {
                        $script:TwitchData.UserInfoCache[$ClipResponse.broadcaster.name] = $ClipResponse.broadcaster.id
                    }

                    # Ensure timestamp was converted correctly
                    $ClipResponse.created_at = $ClipResponse.created_at | ConvertTo-UtcDateTime

                    # Add data to clip cache
                    $script:TwitchData.ClipInfoCache[$Slug] = [StreamXRef.ClipObject]@{
                        Offset  = $ClipResponse.vod.offset
                        VideoID = $VideoID
                        Created = $ClipResponse.created_at
                    }

                    # Add mapping for originating video to clip entry
                    $script:TwitchData.ClipInfoCache[$Slug].Mapping[$ClipResponse.broadcaster.name] = $ClipResponse.vod.url

                    $NewDataAdded = $true

                    # Quick return path for when Target is original broadcaster
                    if ($Target -ieq $ClipResponse.broadcaster.name) {
                        return $ClipResponse.vod.url
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
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                # Set REST arguments
                $RestArgs["Uri"] = "$API/videos/$VideoID"
            }
        }

        # Get absolute timestamp of event
        # Check cache to see if this video is already known
        if (-not $Force -and $script:TwitchData.VideoInfoCache.ContainsKey($VideoID)) {
            # Use start time from cache
            $EventTimestamp = $script:TwitchData.VideoInfoCache[$VideoID] + $TimeOffset
        }
        else {
            # Get information about main video
            $VodResponse = Invoke-RestMethod @RestArgs

            try {
                # Check for incorrect video type
                if ($VodResponse.broadcast_type -ine "archive") {
                    # Set error message based on Source type
                    $ErrSrc = $SourceIsVideo ? "(Video) Source" : "(Clip) Referenced"

                    # Use "ErrorAction Stop" with specific catch block for forwarding
                    Write-Error "$ErrSrc video is not an archived broadcast." -ErrorId InvalidVideoType -Category InvalidOperation -ErrorAction Stop
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
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }

        #endregion Source Lookup =======================

        #region Target Lookup ############################

        if ($TargetIsVideo) {
            # Using VOD link

            # 64-bit integer for future-proofing
            [Int64]$TargetID = $Target | Get-LastUrlSegment
            $RestArgs["Uri"] = "$API/videos/$TargetID"

            $Multi = $false
        }
        else {
            # Using username/channel

            # Strip potential URL formatting
            $Target = $Target | Get-LastUrlSegment

            # Check if repeated search using a name that wasn't found during this instance
            if ($NotFoundList -icontains $Target) {
                Write-Error "(Target Username) `"$Target`" not found." -ErrorId UserNotFound -Category ObjectNotFound -CategoryTargetName Target -TargetObject $Target
                if ($ExplicitNull) {
                    return $null
                }
                else {
                    return
                }
            }

            # Get cached user ID number if available or call API if not
            if (-not $Force -and $script:TwitchData.UserInfoCache.ContainsKey($Target)) {
                $UserIdNum = $script:TwitchData.UserInfoCache[$Target]
            }
            else {
                # Get ID number for username using API
                $RestArgs["Uri"] = "$API/users"
                $RestArgs["Body"] = @{
                    "login" = $Target
                }

                $UserLookup = Invoke-RestMethod @RestArgs

                try {
                    # Unlike other API requests, this doesn't return a 404 error if not found
                    if ($UserLookup._total -eq 0) {
                        $NotFoundList.Add($Target)
                        Write-Error "(Target Username) `"$Target`" not found." -ErrorId UserNotFound -Category ObjectNotFound -CategoryTargetName Target -TargetObject $Target -ErrorAction Stop
                    }

                    [int]$UserIdNum = $UserLookup.users[0]._id

                    # Save ID number in user cache
                    $script:TwitchData.UserInfoCache[$Target] = $UserIdNum
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
            # Check for incorrect video type if Target is a video URL ($Multi will be $false)
            if (-not $Multi -and $XRefResponse.broadcast_type -ine "archive") {
                Write-Error "(Target Video) Video is not an archived broadcast." -ErrorId InvalidVideoType -Category InvalidOperation -CategoryTargetName Target -TargetObject $Target -ErrorAction Stop
            }

            $XRefSet = $Multi ? $XRefResponse.videos : $XRefResponse

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
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        #endregion Target Lookup =========================

        # Look for first video that starts before the timestamp

        try {
            $VideoToCompare = $null
            $VideoToCompare = $XRefSet | Where-Object { $_.recorded_at -lt $EventTimestamp } | Select-Object -First 1

            if ($null -eq $VideoToCompare) {
                Write-Error "Event occurs before search range." -ErrorId EventNotInRange -Category ObjectNotFound -CategoryTargetName EventTimestamp -TargetObject $Source -ErrorAction Stop
            }
            elseif ($EventTimestamp -gt $VideoToCompare.recorded_at.AddSeconds($VideoToCompare.length)) {
                # Event timestamp is after the end of stream
                Write-Error "Event not found during stream." -ErrorId EventNotFound -Category ObjectNotFound -CategoryTargetName EventTimestamp -TargetObject $Source -ErrorAction Stop
            }
            else {
                $NewOffset = $EventTimestamp - $VideoToCompare.recorded_at
                $NewUrl = "$($VideoToCompare.url)?t=$($NewOffset.Hours)h$($NewOffset.Minutes)m$($NewOffset.Seconds)s"

                if (-not $SourceIsVideo -and -not $TargetIsVideo) {
                    try {
                        # Add to clip result mapping
                        $script:TwitchData.ClipInfoCache[$Slug].Mapping[$Target] = $NewUrl
                        $NewDataAdded = $true
                    }
                    catch {
                        Write-Verbose "Unable to add result to clip mapping"
                    }
                }

                return $NewUrl
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
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    End {
        if ((Get-EventSubscriber -SourceIdentifier XRefNewDataAdded -Force -ErrorAction Ignore) -and $NewDataAdded) {
            [void] (New-Event -SourceIdentifier XRefNewDataAdded -Sender "Find-TwitchXRef")
        }
    }
}
