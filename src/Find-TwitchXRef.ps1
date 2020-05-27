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

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1, 100)]
        [int]$Count = 10,

        #region @{ PSCodeSet = Current }
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateRange("NonNegative")]
        [int]$Offset = 0
        #endregion @{ PSCodeSet = Current }
        <# #region @{ PSCodeSet = Legacy }
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({ $_ -ge 0 })]
        [int]$Offset = 0
        #endregion @{ PSCodeSet = Legacy } #>
    )

    DynamicParam {
        $mandAttr = [System.Management.Automation.ParameterAttribute]::new()
        if ($null, "" -contains $script:TwitchData.ApiKey) {
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

                # This also forces script to halt if the command isn't found,
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
                Write-Error "(Video) URL missing timestamp parameter" -ErrorId MissingTimestamp -Category InvalidArgument -CategoryTargetName Source -TargetObject $Source
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

                try {

                    # Get offset from API response
                    [timespan]$TimeOffset = New-TimeSpan -Seconds $ClipResponse.vod.offset

                    # Get Video ID from API response
                    [int]$VideoID = $ClipResponse.vod.id

                }
                catch [System.Management.Automation.PropertyNotFoundException] {

                    # Send error message and skip to next object in pipeline (if any)
                    Write-Error "(Clip) Source video unavailable or deleted" -ErrorId VideoNotFound -Category ObjectNotFound -CategoryTargetName Source -TargetObject $Source
                    return $null

                }

                # Set REST arguments
                $RestArgs["Uri"] = "$API/videos/$VideoID"

                # Add data to clip cache
                $obj = [PSCustomObject]@{
                    Offset  = $ClipResponse.vod.offset
                    VideoID = $VideoID
                }
                $script:TwitchData.ClipInfoCache.Add($Slug, $obj)
                $NewDataAdded = $true

            }

        }

        # Set absolute timestamp of event

        # Check cache to see if this video is already known
        if ($script:TwitchData.VideoInfoCache.ContainsKey($VideoID)) {

            # Use start time from cache
            [datetime]$EventTimestamp = $script:TwitchData.VideoInfoCache[$VideoID] + $TimeOffset

        }
        else {

            # Get information about main video
            $VodResponse = Invoke-RestMethod @RestArgs

            try {

                # Check for incorrect video type
                if ($VodResponse.broadcast_type -ne "archive") {

                    # Set error message based on Source type
                    #region @{ PSCodeSet = Current }
                    $ErrSrc = (Test-Path "Variable:Local:ClipResponse") ? "(Clip) Referenced" : "(Video) Source"
                    #endregion @{ PSCodeSet = Current }
                    #region @{ PSCodeSet = Legacy }
                    if (Test-Path "Variable:Local:ClipResponse") {

                        $ErrSrc = "(Clip) Referenced"

                    }
                    else {

                        $ErrSrc = "(Video) Source"

                    }
                    #endregion @{ PSCodeSet = Legacy }

                    # Use "ErrorAction Stop" with specific catch block for forwarding
                    Write-Error "$ErrSrc video is not an archived broadcast" -ErrorId InvalidVideoType -Category InvalidOperation -ErrorAction Stop

                }

                #region @{ PSCodeSet = Legacy }
                # Manual conversion to UTC datetime
                $VodResponse.recorded_at = $VodResponse.recorded_at | ConvertTo-UtcDateTime
                #endregion @{ PSCodeSet = Legacy }

                # Use start time from API response
                [datetime]$EventTimestamp = $VodResponse.recorded_at + $TimeOffset

            }
            catch [Microsoft.PowerShell.Commands.WriteErrorException] {

                # Write-Error forwarding and skip to next object in pipeline (if any)
                $PSCmdlet.WriteError($_)
                return $null

            }
            catch [System.Management.Automation.PropertyNotFoundException] {

                Write-Host -BackgroundColor Black -ForegroundColor Red "Expected data missing from Twitch API response! Halting:`n"
                $PSCmdlet.ThrowTerminatingError($_)

            }
            catch {

                $PSCmdlet.ThrowTerminatingError($_)

            }

            # Add data to Vod cache
            $script:TwitchData.VideoInfoCache.Add($VideoID, $VodResponse.recorded_at)
            $NewDataAdded = $true

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
            if ($script:TwitchData.UserInfoCache.ContainsKey($XRef)) {

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

                        Write-Error "(XRef) `"$XRef`" not found" -ErrorId UserNotFound -Category ObjectNotFound -CategoryTargetName XRef -TargetObject $XRef -ErrorAction Stop

                    }

                    [int]$UserIdNum = $UserLookup.users[0]._id

                }
                catch [Microsoft.PowerShell.Commands.WriteErrorException] {

                    # Write-Error forwarding and skip to next object in pipeline (if any)
                    $PSCmdlet.WriteError($_)
                    return $null
    
                }
                catch [System.Management.Automation.PropertyNotFoundException] {
    
                    Write-Host -BackgroundColor Black -ForegroundColor Red "(XRef) Expected data missing from Twitch API response! Halting:`n"
                    $PSCmdlet.ThrowTerminatingError($_)
    
                }
                catch {
    
                    $PSCmdlet.ThrowTerminatingError($_)
    
                }

                # Save ID number in cache hashtable
                $script:TwitchData.UserInfoCache.Add($XRef, $UserIdNum)
                $NewDataAdded = $true

            }

            # Set args using ID number
            $RestArgs["Uri"] = "$API/channels/$UserIdNum/videos"
            $RestArgs["Body"] = @{
                "broadcast-type" = "archive"
                "sort"           = "time"
                "limit"          = $Count
                "offset"         = $Offset
            }

            $Multi = $true

        }

        $XRefResponse = Invoke-RestMethod @RestArgs

        # $Multi will be $false if XRef is a video URL
        if (-not $Multi) {

            # Check for incorrect video type
            if ($XRefResponse.broadcast_type -ne "archive") {

                Write-Error "(XRef Video) Video is not an archived broadcast" -ErrorId InvalidVideoType -Category InvalidOperation -CategoryTargetName XRef -TargetObject $XRef
                return $null

            }

        }

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
        $VideoToCompare = $XRefSet | Where-Object { $_.recorded_at -lt $EventTimestamp } | Select-Object -First 1
        if ($null -contains $VideoToCompare) {

            Write-Error "Event occurs before search range" -ErrorId EventNotInRange -Category ObjectNotFound -CategoryTargetName EventTimestamp -TargetObject $Source
            return $null

        }
        elseif ($EventTimestamp -gt $VideoToCompare.recorded_at.AddSeconds($VideoToCompare.length)) {

            # Event timestamp is after the end of stream
            Write-Error "Event not found during stream" -ErrorId EventNotFound -Category ObjectNotFound -CategoryTargetName EventTimestamp -TargetObject $Source
            return $null

        }
        else {

            $NewOffset = $EventTimestamp - $VideoToCompare.recorded_at
            return "$($VideoToCompare.url)?t=$($NewOffset.Hours)h$($NewOffset.Minutes)m$($NewOffset.Seconds)s"

        }

    }

    End {

        if ((Get-EventSubscriber -SourceIdentifier XRefNewDataAdded -Force -ErrorAction Ignore) -and $NewDataAdded) {

            New-Event -SourceIdentifier XRefNewDataAdded -Sender $MyInvocation.Mycommand.Name

        }

    }

}
