#.ExternalHelp StreamXRef-help.xml
function Export-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]$Path,

        [Parameter()]
        [Alias("NoKey", "EAK")]
        [switch]$ExcludeApiKey,

        [Parameter()]
        [Alias("NoMapping", "ECM")]
        [switch]$ExcludeClipMapping,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$NoClobber,

        [Parameter()]
        [switch]$Compress
    )

    Begin {

        if (-not (Test-Path Variable:Script:TwitchData)) {

            throw "Missing required internal resources. Ensure module was loaded correctly."

        }

        if ([string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey) -and $script:TwitchData.GetTotalCount() -eq 0) {

            Write-Warning "No cached data. Exported file will not contain any entries."

        }

        if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {

            $ConfirmPreference = "None"

        }

        # Handle API key
        if ($ExcludeApiKey) {
            $ExportApiKey = ""
        }
        else {
            $ExportApiKey = $script:TwitchData.ApiKey
        }

        $ConvertedUserInfoCache = [System.Collections.Generic.List[pscustomobject]]::new()
        $ConvertedClipInfoCache = [System.Collections.Generic.List[pscustomobject]]::new()
        $ConvertedVideoInfoCache = [System.Collections.Generic.List[pscustomobject]]::new()

        # Convert UserInfoCache to List
        $script:TwitchData.UserInfoCache.GetEnumerator() | ForEach-Object {

            $ConvertedUserInfoCache.Add(
                [pscustomobject]@{
                    name = $_.Key
                    id   = $_.Value
                }
            )

        }

        # Convert ClipInfoCache to List
        $script:TwitchData.ClipInfoCache.GetEnumerator() | ForEach-Object {

            $ClipInfoMapping = [System.Collections.Generic.List[pscustomobject]]::new()

            if (-not $ExcludeClipMapping) {
                # Convert clip mapping data to List
                $_.Value.Mapping.GetEnumerator() | ForEach-Object {
                    $ClipInfoMapping.Add(
                        [pscustomobject]@{
                            user   = $_.Key
                            result = $_.Value
                        }
                    )
                }
            }

            $ConvertedClipInfoCache.Add(
                [pscustomobject]@{
                    slug    = $_.Key
                    offset  = $_.Value.Offset
                    video   = $_.Value.VideoID
                    created = $_.Value.Created.ToString("yyyy-MM-ddTHH:mm:ssZ")
                    mapping = $ClipInfoMapping
                }
            )

        }

        # Convert VideoInfoCache to List
        $script:TwitchData.VideoInfoCache.GetEnumerator() | ForEach-Object {

            # ToString("yyyy-MM-ddTHH:mm:ssZ") specifies format like "2020-05-09T05:35:45Z"
            $ConvertedVideoInfoCache.Add(
                [pscustomobject]@{
                    video     = $_.Key
                    timestamp = $_.Value.ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
            )

        }

        # Bundle data together for converting to JSON (for compatibility with potential Javascript-based version)
        $TXRConfigData = [pscustomobject]@{
            ApiKey         = $ExportApiKey
            UserInfoCache  = $ConvertedUserInfoCache
            ClipInfoCache  = $ConvertedClipInfoCache
            VideoInfoCache = $ConvertedVideoInfoCache
        }

    }

    Process {

        # Save Json string ("-Depth 4" required in order to include clip/username mapping)
        [string]$DataAsJson = $TXRConfigData | ConvertTo-Json -Compress:$Compress -Depth 4

        # Check if path exists
        if (Test-Path $Path) {

            if ($PSCmdlet.ShouldProcess($Path, "Write File")) {

                $DataAsJson | Out-File $Path -Force:$Force -NoClobber:$NoClobber -Confirm:$false

            }

        }
        else {

            # Path doesn't exist

            if ($PSCmdlet.ShouldProcess($Path, "Create File")) {

                # Create placeholder file, including any missing directories
                # Override ErrorAction preferences because Out-File does not create missing directories and will fail anyway
                New-Item $Path -ItemType File -Force:$Force -Confirm:$false -ErrorAction Stop | Out-Null
                $DataAsJson | Out-File $Path -Confirm:$false

            }

        }

    }

}
