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

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Force = $false,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$NoClobber = $false,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Compress = $false
    )

    Begin {

        if ($null, "" -contains $script:TwitchData.ApiKey -and $script:TwitchData.GetTotalCount() -eq 0) {

            Write-Error "No data exists to export"
            return $null

        }

        if ($Force -and -not ($PSBoundParameters.ContainsKey("Confirm") -and $Confirm)) {

            $ConfirmPreference = "None"

        }

        $ConvertedVideoInfoCache = [System.Collections.Generic.Dictionary[string, string]]::new()

    }

    Process {

        # Convert VideoInfoCache to a valid format for serializing
        $script:TwitchData.VideoInfoCache.GetEnumerator() | ForEach-Object {

            # ToString("o") specifies format like "2020-05-09T05:35:45.5032152Z"
            $ConvertedVideoInfoCache.Add($_.Key.ToString(), $_.Value.ToString("o"))

        }

        # Bundle data together for converting to JSON (for compatibility with potential Javascript-based version)
        $TXRConfigData = [pscustomobject]@{
            ApiKey         = $script:TwitchData.ApiKey
            UserInfoCache  = $script:TwitchData.UserInfoCache
            ClipInfoCache  = $script:TwitchData.ClipInfoCache
            VideoInfoCache = $ConvertedVideoInfoCache
        }

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
