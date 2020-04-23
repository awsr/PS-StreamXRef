
<#PSScriptInfo

.VERSION 2.1

.GUID 8c89ef10-5110-4406-a876-82b8eadf5bb2

.AUTHOR Alex

#>

#Requires -Version 7.0

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
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Source,

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
        if ($Source -match ".*twitch\.tv/videos/.+[?&]t=.+") {
            # Video URI provided.
            #region Get offset from URL parameters
            $Source -match ".*[?&]t=((?<Hours>\d+)h)?((?<Minutes>\d+)m)?((?<Seconds>\d+)s)?.*" | Out-Null

            $OffsetArgs = @{}
            $OffsetArgs["Hours"] = ($null -ne $Matches.Hours) ? $Matches.Hours : 0
            $OffsetArgs["Minutes"] = ($null -ne $Matches.Minutes) ? $Matches.Minutes : 0
            $OffsetArgs["Seconds"] = ($null -ne $Matches.Seconds) ? $Matches.Seconds : 0

            $TimeOffset = New-TimeSpan @OffsetArgs
            #endregion

            [int]$VideoID = $Source | Get-IdFromUri

            $RestArgs["Uri"] = ($API, "videos/", $VideoID) | Join-String
        }
        else {
            # Clip provided.
            $Slug = $Source | Get-IdFromUri

            $RestArgs["Uri"] = ($API, "clips/", $Slug) | Join-String

            try {
                $ClipResponse = Invoke-RestMethod @RestArgs
                if (-not ($ClipResponse.vod.offset -and $ClipResponse.vod.id)) {
                    throw "Response Error: (Clip) Required data is missing from API response."
                }
            }
            catch {
                throw $_
            }

            # Get offset from API response.
            $TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset

            # Get Video ID from API response.
            $RestArgs["Uri"] = ($API, "videos/", $ClipResponse.vod.id) | Join-String
        }

        # Get information about main video.
        try {
            $VodResponse = Invoke-RestMethod @RestArgs
            if (-not $VodResponse.recorded_at) {
                throw "Response Error: (Video) Required data is missing from API response."
            }
        }
        catch {
            throw $_
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

            try {
                $UserLookup = Invoke-RestMethod @RestArgs
                if ($UserLookup._total -eq 0) {
                    throw "Input Error: XRef user/channel not found!"
                }
                elseif (-not $UserLookup.users[0]._id) {
                    throw "Response Error: (User Lookup) Required data is missing from API response."
                }
            }
            catch {
                throw $_
            }
            
            [int]$UserID = $UserLookup.users[0]._id

            # Set args using ID number.
            $RestArgs["Uri"] = ($API, "channels/", $UserID, "/videos") | Join-String
            $RestArgs["Body"] = @{
                "broadcast-type" = "archive"
                "sort"           = "time"
                "limit"          = $Count
            }
        }

        try {
            $XRefResponse = Invoke-RestMethod @RestArgs
            if (-not ($XRefResponse.videos.recorded_at -and $XRefResponse.videos.url)) {
                throw "Response Error: (XRef) Required data is missing from API response."
            }
        }
        catch {
            throw $_
        }

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
