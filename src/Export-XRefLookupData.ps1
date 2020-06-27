#.ExternalHelp StreamXRef-help.xml
function Export-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]$Path,

        [Parameter()]
        [switch]$Force = $false,

        [Parameter()]
        [switch]$NoClobber = $false,

        [Parameter()]
        [switch]$Compress = $false
    )

    Begin {

        if ([string]::IsNullOrWhiteSpace($script:TwitchData.ApiKey) -and $script:TwitchData.GetTotalCount() -eq 0 -and -not $Force) {

            Write-Warning "No data exists to export. Use -Force to write a placeholder file."
            break

        }

        if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {

            $ConfirmPreference = "None"

        }

        $ConvertedUserInfoCache = [System.Collections.ArrayList]::new()
        $ConvertedClipInfoCache = [System.Collections.ArrayList]::new()
        $ConvertedVideoInfoCache = [System.Collections.ArrayList]::new()

        # Convert UserInfoCache to ArrayList
        $script:TwitchData.UserInfoCache.GetEnumerator() | ForEach-Object {

            [void]$ConvertedUserInfoCache.Add(
                [pscustomobject]@{
                    name = $_.Key
                    id   = $_.Value
                }
            )

        }

        # Convert ClipInfoCache to ArrayList
        $script:TwitchData.ClipInfoCache.GetEnumerator() | ForEach-Object {

            [void]$ConvertedClipInfoCache.Add(
                [pscustomobject]@{
                    slug    = $_.Key
                    offset  = $_.Value.Offset
                    video   = $_.Value.VideoID
                    created = $_.Value.Created.ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
            )

        }

        # Convert VideoInfoCache to ArrayList
        $script:TwitchData.VideoInfoCache.GetEnumerator() | ForEach-Object {

            # ToString("yyyy-MM-ddTHH:mm:ssZ") specifies format like "2020-05-09T05:35:45Z"
            [void]$ConvertedVideoInfoCache.Add(
                [pscustomobject]@{
                    video     = $_.Key
                    timestamp = $_.Value.ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
            )

        }

        # Bundle data together for converting to JSON (for compatibility with potential Javascript-based version)
        $TXRConfigData = [pscustomobject]@{
            ApiKey         = $script:TwitchData.ApiKey
            UserInfoCache  = $ConvertedUserInfoCache
            ClipInfoCache  = $ConvertedClipInfoCache
            VideoInfoCache = $ConvertedVideoInfoCache
        }

    }

    Process {

        # Save Json string
        [string]$DataAsJson = $TXRConfigData | ConvertTo-Json -Compress:$Compress

        # Check if path exists
        if (Test-Path $Path) {

            if ($PSCmdlet.ShouldProcess($Path, "Write File")) {

                $DataAsJson | Out-File $Path -Force:$Force -NoClobber:$NoClobber

            }

        }
        else {

            # Path doesn't exist

            if ($PSCmdlet.ShouldProcess($Path, "Create File")) {

                # Create placeholder file, including any missing directories
                # Override ErrorAction preferences because Out-File does not create missing directories and will fail anyway
                New-Item $Path -ItemType File -Force:$Force -ErrorAction Stop | Out-Null
                $DataAsJson | Out-File $Path

            }

        }

    }

}
