
<#PSScriptInfo

.VERSION 2.2.1

.GUID 8c89ef10-5110-4406-a876-82b8eadf5bb2

.AUTHOR Alex

#>

#Requires -Version 5.1

<# 

.DESCRIPTION 
 Cross-reference timestamps for VODs and clips between different channels/users.
 This version of the script works with Windows PowerShell 5.1.

 You must provide a Client ID the first time the function is run.

.PARAMETER Source
 Accepts Twitch clips in either URL format, Twitch clip IDs, or video URLs that include a timestamp parameter.

.PARAMETER XRef
 Accepts either a video URL, a channel URL, or a channel/user name.

.PARAMETER Count
 Number of videos to search when -XRef is a name. Default: 10

.PARAMETER ClientID
 REQUIRED when run for the first time in a session.
 Accepts your Twitch API client ID.

.PARAMETER PassThru
 Returns result URL as a string instead of writing to host.

.NOTES
 This uses the v5 Twitch API.

#>

function global:Get-TwitchXRef {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$XRef,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1,100)]
        [int]$Count = 10,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$ClientID = $global:Twitch_API_ClientID,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$PassThru = $false
    )

    Begin {
        $API = "https://api.twitch.tv/kraken/"

        if ($null, "" -contains $ClientID) {
            $ClientID = Read-Host "Enter ClientID"
        }
        $global:Twitch_API_ClientID = $ClientID

        $v5Headers = @{
            "Client-ID" = $ClientID
            "Accept"    = "application/vnd.twitchtv.v5+json"
        }

        filter Get-IdFromUri {
            $Uri = $_ -split "/" | Select-Object -Last 1
            return $Uri -split "\?" | Select-Object -First 1
        }
    }

    Process {
        if ($null, "" -contains $ClientID) {
            throw "No Twitch API client ID specified or found."
        }

        $RestArgs = @{
            Method      = "Get"
            Headers     = $v5Headers
            ErrorAction = "Stop"
        }
        
        if ($Source -match ".*twitch\.tv/videos/.+") {
            # Video URI provided.
            if ($Source -notmatch ".*twitch\.tv/videos/.+[?&]t=.+") {
                throw "Input Error: Video URL missing timestamp parameter."
            }

            #region Get offset from URL parameters
            $Source -match ".*[?&]t=((?<Hours>\d+)h)?((?<Minutes>\d+)m)?((?<Seconds>\d+)s)?.*" | Out-Null

            #region Old method of setting values. <BackCompat!>
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
            #endregion

            $TimeOffset = New-TimeSpan @OffsetArgs
            #endregion

            [int]$VideoID = $Source | Get-IdFromUri

            $RestArgs["Uri"] = $API + "videos/" + $VideoID # <BackCompat!>
        }
        else {
            # Clip provided.
            $Slug = $Source | Get-IdFromUri

            $RestArgs["Uri"] = $API + "clips/" + $Slug # <BackCompat!>

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
            $RestArgs["Uri"] = $API + "videos/" + $ClipResponse.vod.id # <BackCompat!>
        }

        # Get information about main video.
        try {
            $VodResponse = Invoke-RestMethod @RestArgs
            if (-not $VodResponse.recorded_at) {
                throw "Response Error: (Video) Required data is missing from API response."
            }
            else {
                # Manual conversion to UTC datetime. <BackCompat!>
                $VodResponse.recorded_at = ([datetime]::Parse($VodResponse.recorded_at)).ToUniversalTime()
            }
        }
        catch {
            throw $_
        }

        # Set absolute timestamp of event.
        [datetime]$EventTimestamp = $VodResponse.recorded_at + $TimeOffset

        # ========================================

        # Process cross-reference lookup.
        if ($XRef -match ".*twitch\.tv/videos/.+") {
            # Using VOD link.
            [int]$XRefID = $XRef | Get-IdFromUri
            $RestArgs["Uri"] = $API + "videos/" + $XRefID # <BackCompat!>
        }
        else {
            # Using username.

            # Strip formatting in case channel was passed as a URL.
            $XRef = $XRef | Get-IdFromUri

            # Get ID number for username.
            $RestArgs["Uri"] = $API + "users" # <BackCompat!>
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
            $RestArgs["Uri"] = $API + "channels/" + $UserID + "/videos" # <BackCompat!>
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
            else {
                # Manual conversion to UTC datetime. <BackCompat!>
                for ($i = 0; $i -lt $XRefResponse.videos.Length; $i++) {
                    $XRefResponse.videos[$i].recorded_at = ([datetime]::Parse($XRefResponse.videos[$i].recorded_at)).ToUniversalTime()
                }
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

Write-Host -NoNewline "Command loaded: "
Write-Host -ForegroundColor Green "Get-TwitchXRef"

if (Test-Path Alias:gtx) {
    # Alias already exists...
    if ((Get-Alias gtx).Definition -ne "Get-TwitchXRef") {
        # ... but is set to some other command.
        Write-Warning "Alias already exists: $((Get-Alias gtx).DisplayName)"

        if ((Read-Host "Overwrite alias? (y/n)") -like "y") {
            Set-Alias -Name "gtx" -Value Get-TwitchXRef -Scope Global -Force
            Write-Host -NoNewline "Alias set to: "
            Write-Host -ForegroundColor Green "gtx"
        }
    }
}
else {
    # Add alias.
    New-Alias -Name "gtx" -Value Get-TwitchXRef -Scope Global
    Write-Host -NoNewline "Alias set to: "
    Write-Host -ForegroundColor Green "gtx"
}
