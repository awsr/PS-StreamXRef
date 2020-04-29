<# 

.SYNOPSIS
 Cross-reference Twitch clips and video timestamps between different channels/users.

.DESCRIPTION 
 Given a Twitch clip or video timestamp URL, get a URL to the same moment from the cross-referenced video or channel.

 You must provide a Client ID the first time the function is run.

.PARAMETER Source
 Accepts Twitch clip URLs (either format), Twitch clip IDs, or video URLs that include a timestamp parameter.

.PARAMETER XRef
 Accepts either a video URL, a channel URL, or a channel/user name.

.PARAMETER ClientID
 Accepts your Twitch API client ID.

 (REQUIRED when run for the first time in a session.)

.PARAMETER Count
 Number of videos to search when -XRef is a name.
 Default: 10

.PARAMETER Offset
 Number of results to offset the search range by.
 Default: 0

 (Useful if the source is older than 100 results.)

.NOTES
 This uses the v5 Twitch API.

#>
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
        if ($null, "" -contains $script:Twitch_API_ClientID) {
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
        $API = "https://api.twitch.tv/kraken/"

        if ($PSBoundParameters.ContainsKey("ClientID")) {
            $ClientID = $PSBoundParameters.ClientID
            $script:Twitch_API_ClientID = $PSBoundParameters.ClientID
        }
        else {
            $ClientID = $script:Twitch_API_ClientID
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
        
        if ($Source -match ".*twitch\.tv/videos/.+") {
            # Video URI provided
            if ($Source -notmatch ".*twitch\.tv/videos/.+[?&]t=.+") {
                Write-Error "Video URL missing timestamp parameter" -ErrorID MissingTimestamp -Category SyntaxError -CategoryTargetName "Source" -TargetObject $Source
                return $null
            }

            #region Get offset from URL parameters
            $Source -match ".*[?&]t=((?<Hours>\d+)h)?((?<Minutes>\d+)m)?((?<Seconds>\d+)s)?.*" | Out-Null

            #region Old method of setting values. <!Legacy>
            $OffsetArgs = @{
                Hours = 0
                Minutes = 0
                Seconds = 0
            }
            if ($null -ne $Matches.Hours) {
                $OffsetArgs["Hours"] = $Matches.Hours
            }
            if ($null -ne $Matches.Minutes) {
                $OffsetArgs["Minutes"] = $Matches.Minutes
            }
            if ($null -ne $Matches.Seconds) {
                $OffsetArgs["Seconds"] = $Matches.Seconds
            }
            #endregion <!Legacy>

            $TimeOffset = New-TimeSpan @OffsetArgs
            #endregion

            [int]$VideoID = $Source | Get-IdFromUri

            $RestArgs["Uri"] = "$($API)videos/$VideoID" # <!Legacy>
        }
        else {
            # Clip provided
            $Slug = $Source | Get-IdFromUri

            $RestArgs["Uri"] = "$($API)clips/$Slug" # <!Legacy>

            $ClipResponse = Invoke-RestMethod @RestArgs

            # Get offset from API response
            $TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset

            # Get Video ID from API response
            $RestArgs["Uri"] = "$($API)videos/$($ClipResponse.vod.id)" # <!Legacy>
        }

        # Get information about main video
        $VodResponse = Invoke-RestMethod @RestArgs

        # Manual conversion to UTC datetime <!Legacy>
        $VodResponse.recorded_at = ([datetime]::Parse($VodResponse.recorded_at)).ToUniversalTime()

        # Set absolute timestamp of event
        [datetime]$EventTimestamp = $VodResponse.recorded_at + $TimeOffset

        # ========================================

        # Process cross-reference lookup
        if ($XRef -match ".*twitch\.tv/videos/.+") {
            # Using VOD link
            [int]$XRefID = $XRef | Get-IdFromUri
            $RestArgs["Uri"] = "$($API)videos/$XRefID" # <!Legacy>
        }
        else {
            # Using username/channel
            # Strip formatting in case channel was passed as a URL
            $XRef = $XRef | Get-IdFromUri

            # Check ID cache for user
            if ($script:Twitch_API_UserIDCache.ContainsKey($XRef)) {
                # Use cached ID number
                [int]$UserIDNum = $script:Twitch_API_UserIDCache[$XRef]
            }
            else {
                # Get ID number for username using API
                $RestArgs["Uri"] = ($API, "users") | Join-String
                $RestArgs["Body"] = @{
                    "login" = $XRef
                }

                $UserLookup = Invoke-RestMethod @RestArgs
                if ($UserLookup._total -eq 0) {
                    Write-Error "(XRef Channel/User) Not found" -ErrorID UserNotFound -Category ObjectNotFound -CategoryTargetName "XRef" -TargetObject $XRef
                    return $null
                }
                
                [int]$UserIDNum = $UserLookup.users[0]._id

                # Save ID number in cache hashtable
                $script:Twitch_API_UserIDCache.Add($XRef, $UserIDNum)
            }

            # Set args using ID number
            $RestArgs["Uri"] = "$($API)channels/$UserIDNum/videos" # <!Legacy>
            $RestArgs["Body"] = @{
                "broadcast-type" = "archive"
                "sort"           = "time"
                "limit"          = $Count
                "offset"         = $Offset
            }
        }

        $XRefResponse = Invoke-RestMethod @RestArgs

        # Manual conversion to UTC datetime <!Legacy>
        for ($i = 0; $i -lt $XRefResponse.videos.length; $i++) {
            $XRefResponse.videos[$i].recorded_at = ([datetime]::Parse($XRefResponse.videos[$i].recorded_at)).ToUniversalTime()
        }

        # ========================================

        # Look for first video that starts before the timestamp
        $VideoToCompare = $null
        $VideoToCompare = $XRefResponse.videos | Where-Object -Property "recorded_at" -LT $EventTimestamp | Select-Object -First 1
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
