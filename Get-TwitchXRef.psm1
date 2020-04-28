
Set-StrictMode -Version Latest

# Initialize to null
$script:Twitch_API_ClientID = $null

# Helper function
filter Get-IdFromUri {
    $Uri = $_ -split "/" | Select-Object -Last 1
    return $Uri -split "\?" | Select-Object -First 1
}


<# 

.SYNOPSIS
 Cross-reference Twitch clips and video timestamps between different channels/users.

.DESCRIPTION 
 Given a Twitch clip or video timestamp URL, get a URL to the same moment from the cross-referenced video or channel.

 You must provide a Client ID the first time the function is run.

.PARAMETER Source
 Accepts Twitch clips in either URL format, Twitch clip IDs, or video URLs that include a timestamp parameter.

.PARAMETER XRef
 Accepts either a video URL, a channel URL, or a channel/user name.

.PARAMETER ClientID
 REQUIRED when run for the first time in a session.
 Accepts your Twitch API client ID.

.PARAMETER Count
 Number of videos to search when -XRef is a name. Default: 10

.PARAMETER Offset
 Number of results to offset the search range by. Default: 0
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

            $OffsetArgs = @{ }
            $OffsetArgs["Hours"] = ($null -ne $Matches.Hours) ? $Matches.Hours : 0
            $OffsetArgs["Minutes"] = ($null -ne $Matches.Minutes) ? $Matches.Minutes : 0
            $OffsetArgs["Seconds"] = ($null -ne $Matches.Seconds) ? $Matches.Seconds : 0

            $TimeOffset = New-TimeSpan @OffsetArgs
            #endregion

            [int]$VideoID = $Source | Get-IdFromUri

            $RestArgs["Uri"] = ($API, "videos/", $VideoID) | Join-String
        }
        else {
            # Clip provided
            $Slug = $Source | Get-IdFromUri

            $RestArgs["Uri"] = ($API, "clips/", $Slug) | Join-String

            $ClipResponse = Invoke-RestMethod @RestArgs

            # Get offset from API response
            $TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset

            # Get Video ID from API response
            $RestArgs["Uri"] = ($API, "videos/", $ClipResponse.vod.id) | Join-String
        }

        # Get information about main video
        $VodResponse = Invoke-RestMethod @RestArgs

        # Set absolute timestamp of event
        [datetime]$EventTimestamp = $VodResponse.recorded_at + $TimeOffset

        # ========================================

        # Process cross-reference lookup
        if ($XRef -match ".*twitch\.tv/videos/.+") {
            # Using VOD link
            [int]$XRefID = $XRef | Get-IdFromUri
            $RestArgs["Uri"] = ($API, "videos/", $XRefID) | Join-String
        }
        else {
            # Using username/channel
            # Strip formatting in case channel was passed as a URL
            $XRef = $XRef | Get-IdFromUri

            # Get ID number for username
            $RestArgs["Uri"] = ($API, "users") | Join-String
            $RestArgs["Body"] = @{
                "login" = $XRef
            }

            $UserLookup = Invoke-RestMethod @RestArgs
            if ($UserLookup._total -eq 0) {
                Write-Error "(XRef Channel/User) Not found" -ErrorID UserNotFound -Category ObjectNotFound -CategoryTargetName "XRef" -TargetObject $XRef
                return $null
            }
            
            [int]$UserID = $UserLookup.users[0]._id

            # Set args using ID number
            $RestArgs["Uri"] = ($API, "channels/", $UserID, "/videos") | Join-String
            $RestArgs["Body"] = @{
                "broadcast-type" = "archive"
                "sort"           = "time"
                "limit"          = $Count
                "offset"         = $Offset
            }
        }

        $XRefResponse = Invoke-RestMethod @RestArgs

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

Set-Alias -Name gtxr -Value Get-TwitchXRef

Export-ModuleMember -Alias "gtxr" -Variable "Twitch_API_ClientID"
