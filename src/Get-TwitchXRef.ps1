#.EnablePSCodeSets
#.ExternalHelp Get-TwitchXRef-help.xml
function Get-TwitchXRef {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$XRef,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1, 100)]
        [int]$Count = 10,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateRange("NonNegative")]
        [int]$Offset = 0
    )

    DynamicParam {
        $mandAttr = [System.Management.Automation.ParameterAttribute]::new()
        if ($null, "" -contains $script:TwitchData.ClientID) {
            $mandAttr.Mandatory = $true
        }
        else {
            $mandAttr.Mandatory = $false
        }

        $vnnoeAttr = [System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new()
        $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
        $attributeCollection.Add($mandAttr)
        $attributeCollection.Add($vnnoeAttr)

        $dynParam1 = [System.Management.Automation.RuntimeDefinedParameter]::new("ClientID", [string], $attributeCollection)

        $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $paramDictionary.Add("ClientID", $dynParam1)
        return $paramDictionary
    }

    Begin {
        $API = "https://api.twitch.tv/kraken"

        if ($PSBoundParameters.ContainsKey("ClientID")) {
            $ClientID = $PSBoundParameters.ClientID
            $script:TwitchData.ClientID = $PSBoundParameters.ClientID
        }
        else {
            $ClientID = $script:TwitchData.ClientID
        }

        $v5Headers = @{
            "Client-ID" = $ClientID
            "Accept"    = "application/vnd.twitchtv.v5+json"
        }
    }

    Process {
        trap [Microsoft.PowerShell.Commands.HttpResponseException] {
            # API Responded with error status
            if ($_.Exception.Response.StatusCode -eq 404) {
                # Not found
                $PSCmdlet.WriteError($_)
                return $null
            }
            else {
                # Other error status codes
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        trap [System.Net.Http.HttpRequestException] {
            # Other http request errors
            # Parent to HttpResponseException so it must go after
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $RestArgs = @{
            Method      = "Get"
            Headers     = $v5Headers
            ErrorAction = "Stop"
        }
        
        #region Source Lookup ##########################

        if ($Source -match ".*twitch\.tv/videos/.+") {
            # Video URL provided

            # Check if missing timestamp
            if ($Source -notmatch ".*twitch\.tv/videos/.+[?&]t=.+") {
                Write-Error "Video URL missing timestamp parameter" -ErrorID MissingTimestamp -Category SyntaxError -CategoryTargetName "Source" -TargetObject $Source
                return $null
            }

            #region Get offset from URL parameters
            $Source -match ".*[?&]t=((?<Hours>\d+)h)?((?<Minutes>\d+)m)?((?<Seconds>\d+)s)?.*" | Out-Null

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

            $Slug = $Source | Get-LastUrlSegment

            if ($script:TwitchData.ClipInfoCache.ContainsKey($Slug)) {
                # Found cached values to use

                [timespan]$TimeOffset = New-TimeSpan -Seconds $script:TwitchData.ClipInfoCache[$Slug].Offset
                [int]$VideoID = $script:TwitchData.ClipInfoCache[$Slug].VideoID
                
                # Set REST arguments
                $RestArgs["Uri"] = "$API/videos/$VideoID"
            }
            else {
                # New uncached source ---- needs additional API call

                # Get information about clip
                $RestArgs["Uri"] = "$API/clips/$Slug"
                $ClipResponse = Invoke-RestMethod @RestArgs
    
                # Get offset from API response
                [timespan]$TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset
    
                # Get Video ID from API response
                [int]$VideoID = $ClipResponse.vod.id

                # Set REST arguments
                $RestArgs["Uri"] = "$API/videos/$VideoID"
                
                # Add data to clip cache (StrictMode will have thrown an error by now if it wasn't found)
                $obj = [PSCustomObject]@{
                    Offset  = $ClipResponse.vod.offset
                    VideoID = $VideoID
                }
                $script:TwitchData.ClipInfoCache.Add($Slug, $obj)
            }
        }

        # Set absolute timestamp of event
        if ($script:TwitchData.VideoStartCache.ContainsKey($VideoID)) {
            # Use start time from cache
            [datetime]$EventTimestamp = $script:TwitchData.VideoStartCache[$VideoID] + $TimeOffset
        }
        else {
            # Get information about main video
            $VodResponse = Invoke-RestMethod @RestArgs

            #region @{ PSCodeSet = Legacy }
            # Manual conversion to UTC datetime <!Legacy>
            $VodResponse.recorded_at = $VodResponse.recorded_at | ConvertTo-UtcDateTime
            #endregion @{ PSCodeSet = Legacy }

            # Use start time from API response
            [datetime]$EventTimestamp = $VodResponse.recorded_at + $TimeOffset

            # Add data to Vod cache
            $script:TwitchData.VideoStartCache.Add($VideoID, $VodResponse.recorded_at)
        }

        #endregion Source Lookup =======================

        #region XRef Lookup ############################

        if ($XRef -match ".*twitch\.tv/videos/.+") {
            # Using VOD link

            [int]$XRefID = $XRef | Get-LastUrlSegment
            $RestArgs["Uri"] = "$API/videos/$XRefID"

            $Multi = $false
        }
        else {
            # Using username/channel

            # Strip formatting in case channel was passed as a URL
            $XRef = $XRef | Get-LastUrlSegment

            # Check ID cache for user
            if ($script:TwitchData.UserIDCache.ContainsKey($XRef)) {
                # Use cached ID number
                [int]$UserIDNum = $script:TwitchData.UserIDCache[$XRef]
            }
            else {
                # Get ID number for username using API
                $RestArgs["Uri"] = "$API/users"
                $RestArgs["Body"] = @{
                    "login" = $XRef
                }

                $UserLookup = Invoke-RestMethod @RestArgs
                if ($UserLookup._total -eq 0) {
                    Write-Error "(XRef Channel/User) `"$XRef`" not found" -ErrorID UserNotFound -Category ObjectNotFound -CategoryTargetName "XRef" -TargetObject $XRef
                    return $null
                }
                
                [int]$UserIDNum = $UserLookup.users[0]._id

                # Save ID number in cache hashtable
                $script:TwitchData.UserIDCache.Add($XRef, $UserIDNum)
            }

            # Set args using ID number
            $RestArgs["Uri"] = "$API/channels/$UserIDNum/videos"
            $RestArgs["Body"] = @{
                "broadcast-type" = "archive"
                "sort"           = "time"
                "limit"          = $Count
                "offset"         = $Offset
            }

            $Multi = $true
        }

        $XRefResponse = Invoke-RestMethod @RestArgs

        #region @{ PSCodeSet = Current }
        $XRefSet = $Multi ? $XRefResponse.videos : $XRefResponse
        #endregion @{ PSCodeSet = Current }
        #region @{ PSCodeSet = Legacy }
        if ($Multi) {
            $XRefSet = $XRefResponse.videos

            # Manual conversion to UTC datetime
            for ($i = 0; $i -lt $XRefSet.length; $i++) {
                $XRefSet[$i].recorded_at = $XRefSet[$i].recorded_at | ConvertTo-UtcDateTime
            }
        }
        else {
            $XRefSet = $XRefResponse

            # Manual conversion to UTC datetime
            $XRefSet.recorded_at = $XRefSet.recorded_at | ConvertTo-UtcDateTime
        }
        #endregion @{ PSCodeSet = Legacy }

        #endregion XRef Lookup =========================

        # Look for first video that starts before the timestamp
        $VideoToCompare = $null
        $VideoToCompare = $XRefSet | Where-Object -Property "recorded_at" -LT $EventTimestamp | Select-Object -First 1
        if ($null -contains $VideoToCompare) {
            Write-Error "Event occurs before search range" -ErrorID EventNotInRange -Category ObjectNotFound -CategoryTargetName "EventTimestamp" -TargetObject $Source
            return $null
        }
        elseif ($EventTimestamp -gt $VideoToCompare.recorded_at.AddSeconds($VideoToCompare.length)) {
            # Event timestamp is after the end of stream
            Write-Error "Event not found during stream" -ErrorId EventNotFound -Category ObjectNotFound -CategoryTargetName "EventTimestamp" -TargetObject $Source
            return $null
        }
        else {
            $NewOffset = $EventTimestamp - $VideoToCompare.recorded_at
            $NewUrl = "$($VideoToCompare.url)?t=$($NewOffset.Hours)h$($NewOffset.Minutes)m$($NewOffset.Seconds)s"
        }

        return $NewUrl
    }
}
