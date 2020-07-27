using namespace System.Collections.Generic
#.ExternalHelp StreamXRef-help.xml
function Export-XRefData {
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

        if ([string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey) -and $script:TwitchData.GetTotalCount() -eq 0) {

            Write-Warning "No cached data. Exported file will not contain any entries."

        }

        if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {

            $ConfirmPreference = "None"

        }

        # DateTime string formatting ("yyyy-MM-ddTHH:mm:ssZ" -> "2020-05-09T05:35:45Z")
        $DateTimeFormatting = "yyyy-MM-ddTHH:mm:ssZ"

        # Handle API key
        if ($ExcludeApiKey) {
            $ExportApiKey = ""
        }
        else {
            $ExportApiKey = $script:TwitchData.ApiKey
        }

        $ConvertedUserInfoCache = [List[pscustomobject]]::new()
        $ConvertedClipInfoCache = [List[pscustomobject]]::new()
        $ConvertedVideoInfoCache = [List[pscustomobject]]::new()

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

            $ClipMappingList = [List[pscustomobject]]::new()

            if (-not $ExcludeClipMapping) {
                # Convert clip mapping data to List
                $_.Value.Mapping.GetEnumerator() | ForEach-Object {
                    $ClipMappingList.Add(
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
                    created = $_.Value.Created.ToString($DateTimeFormatting)
                    mapping = $ClipMappingList
                }
            )

        }

        # Convert VideoInfoCache to List
        $script:TwitchData.VideoInfoCache.GetEnumerator() | ForEach-Object {

            $ConvertedVideoInfoCache.Add(
                [pscustomobject]@{
                    video     = $_.Key
                    timestamp = $_.Value.ToString($DateTimeFormatting)
                }
            )

        }

        # Bundle data together for converting to JSON (for compatibility with potential Javascript-based version)
        $StagedTwitchData = [pscustomobject]@{
            ApiKey         = $ExportApiKey
            UserInfoCache  = $ConvertedUserInfoCache
            ClipInfoCache  = $ConvertedClipInfoCache
            VideoInfoCache = $ConvertedVideoInfoCache
        }

    }

    Process {

        # Save Json string ("-Depth 4" required in order to include clip/username mapping)
        $DataAsJson = $StagedTwitchData | ConvertTo-Json -Compress:$Compress -Depth 4

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
                [void] (New-Item $Path -ItemType File -Force:$Force -Confirm:$false -ErrorAction Stop)
                $DataAsJson | Out-File $Path -Confirm:$false

            }

        }

    }

}
