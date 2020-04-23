
<#PSScriptInfo

.VERSION 1.0

.GUID 8c89ef10-5110-4406-a876-82b8eadf5bb2

.AUTHOR Alex

#>

<# 

.DESCRIPTION 
 Cross-reference timestamps for VODs and clips between different users.

 You must provide a Client ID the first time the function is run.

.NOTES
 This uses the v5 Twitch API.

#>

function global:Get-TwitchXRef {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "Clip", Position = 0)]
        [ValidatePattern(".*twitch\.tv/.+")]
        [string]$Clip,

        [Parameter(Mandatory = $true, ParameterSetName = "VideoUri", Position = 0)]
        [ValidatePattern(".*twitch\.tv/videos/.+[?&]t=.+")]
        [string]$VideoUri,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$XRef,

        [Parameter()]
        [ValidateRange(1,100)]
        [int]$Count = 10,

        [Parameter()]
        [string]$ClientID = $global:Twitch_API_ClientID,

        [Parameter()]
        [switch]$PassThru
    )

    Begin {
        $API = "https://api.twitch.tv/kraken/"

        if (-not $ClientID) {
            $ClientID = Read-Host "Enter ClientID"
        }
        $global:Twitch_API_ClientID = $ClientID

        $v5Headers = @{
            "Client-ID" = $ClientID
            "Accept"    = "application/vnd.twitchtv.v5+json"
        }

        $RestArgs = @{
            Method      = "Get"
            Headers     = $v5Headers
            ErrorAction = "Stop"
        }

        filter Get-IdFromUri {
            $Uri = $_ -split "/" | Select-Object -Last 1
            return $Uri -split "\?" | Select-Object -First 1
        }
    }

    Process {
        if ($Clip) {
            # Get VOD from clip.
            $Slug = $Clip | Get-IdFromUri

            $RestArgs["Uri"] = ($API, "clips/", $Slug) | Join-String

            $ClipResponse = Invoke-RestMethod @RestArgs
            if ($ClipResponse.error) {
                throw "API Error: $($ClipResponse.status) $($ClipResponse.error)."
            }
            if (-not $ClipResponse.vod.offset) {
                throw "Response Error: Time offset missing from API response."
            }
            if (-not $ClipResponse.vod.id) {
                throw "Response Error: VOD ID missing from API response."
            }

            # Get offset from API response.
            $TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset

            $RestArgs["Uri"] = ($API, "videos/", $ClipResponse.vod.id) | Join-String

        }
        else {
            # VOD already provided.
            #region Get offset from URL parameters
            $VideoUri -match ".*[?&]t=((?<Hours>\d+)h)?((?<Minutes>\d+)m)?((?<Seconds>\d+)s)?.*" | Out-Null

            $OffsetArgs = @{}
            $OffsetArgs["Hours"] = ($null -ne $Matches.Hours) ? $Matches.Hours : 0
            $OffsetArgs["Minutes"] = ($null -ne $Matches.Minutes) ? $Matches.Minutes : 0
            $OffsetArgs["Seconds"] = ($null -ne $Matches.Seconds) ? $Matches.Seconds : 0

            $TimeOffset = New-TimeSpan @OffsetArgs
            #endregion

            [int]$VideoID = $VideoUri | Get-IdFromUri

            $RestArgs["Uri"] = ($API, "videos/", $VideoID) | Join-String
        }

        # Get information about main video.
        $VodResponse = Invoke-RestMethod @RestArgs
        if ($VodResponse.error) {
            throw "API Error: $($VodResponse.status) $($VodResponse.error)."
        }
        if (-not $VodResponse.recorded_at) {
            throw "Response Error: Source video start time missing from API response."
        }

        # Set absolute timestamp of event.
        $EventTimestamp = $VodResponse.recorded_at + $TimeOffset

        # ========================================

        # Process cross-reference lookup.
        if ($XRef -match ".*twitch\.tv/videos/.+") {
            # Using VOD link.
            [int]$XRefID = $XRef | Get-IdFromUri
            $RestArgs["Uri"] = ($API, "videos/", $XRefID) | Join-String
        }
        else {
            # Using username.

            # Strip formatting in case channel was passed as a URL.
            $XRef = $XRef | Get-IdFromUri

            # Get ID number for username.
            $RestArgs["Uri"] = ($API, "users") | Join-String
            $RestArgs["Body"] = @{
                "login" = $XRef
            }
            $UserLookup = Invoke-RestMethod @RestArgs
            [int]$UserID = $UserLookup.users[0]._id

            # Set args using ID number.
            $RestArgs["Uri"] = ($API, "channels/", $UserID, "/videos") | Join-String
            $RestArgs["Body"] = @{
                "broadcast-type" = "archive"
                "sort"           = "time"
                "limit"          = $Count
            }
        }

        $XRefResponse = Invoke-RestMethod @RestArgs

        # ========================================

        # Look for first video that starts before the timestamp.
        $VideoToCompare = $XRefResponse.videos | Where-Object -Property "recorded_at" -LT $EventTimestamp | Select-Object -First 1
        if (-not $VideoToCompare) {
            throw "Event occurs before search range."
        }
        elseif (-not $VideoToCompare.recorded_at.AddSeconds($VideoToCompare.length) -gt $EventTimestamp) {
            # End time isn't after timestamp.
            throw "Event not found during stream."
        }
        else {
            $NewOffset = $EventTimestamp - $VideoToCompare.recorded_at
            $NewUrl = "$($VideoToCompare.url)?t=$($NewOffset.Hours)h$($NewOffset.Minutes)m$($NewOffset.Seconds)s"
        }

        if ($PassThru) {
            return $NewUrl
        }
        else {
            Write-Host -BackgroundColor Black -ForegroundColor Green "$NewUrl"
        }
    }
}

New-Alias -Name "gtx" -Value Get-TwitchXRef -Scope Global

Write-Host -NoNewline "Command "
Write-Host -NoNewline -ForegroundColor Green "Get-TwitchXRef"
Write-Host -NoNewline " loaded. Alias: "
Write-Host -ForegroundColor Green "gtx"
