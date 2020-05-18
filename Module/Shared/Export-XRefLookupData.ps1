#.ExternalHelp StreamXRef-help.xml
function Export-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium", DefaultParameterSetName = "Object")]
    [OutputType([System.Void], ParameterSetName = "File")]
    [OutputType([System.String], ParameterSetName = "Object")]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "File",
                   ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]$Path,

        [Parameter(ParameterSetName = "File", ValueFromPipelineByPropertyName = $true)]
        [switch]$Force = $false,

        [Parameter(ParameterSetName = "Object", ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = "File", ValueFromPipelineByPropertyName = $true)]
        [switch]$Compress = $false
    )

    Begin {

        if ($null, "" -contains $script:TwitchData.ApiKey -and $script:TwitchData.GetTotalCount() -eq 0) {

            Write-Error "No data exists to export"
            return $null

        }

        if ($PSCmdlet.ParameterSetName -eq "File") {

            if ($Force -and -not ($PSBoundParameters.ContainsKey("Confirm") -and $Confirm)) {

                $ConfirmPreference = "None"
    
            }

        }

        $ConvertedVideoStartCache = [System.Collections.Generic.Dictionary[string, string]]::new()

    }

    Process {

        # Convert VideoStartCache to a valid format for serializing
        $script:TwitchData.VideoStartCache.GetEnumerator() | ForEach-Object {

            # ToString("o") specifies format like "2020-05-09T05:35:45.5032152Z"
            $ConvertedVideoStartCache.Add($_.Key.ToString(), $_.Value.ToString("o"))

        }

        # Bundle data together for converting to JSON (for compatibility with potential Javascript-based version)
        $TXRConfigData = [pscustomobject]@{
            ApiKey          = $script:TwitchData.ApiKey
            UserIdCache     = $script:TwitchData.UserIdCache
            ClipInfoCache   = $script:TwitchData.ClipInfoCache
            VideoStartCache = $ConvertedVideoStartCache
        }

        # Save Json string
        [string]$DataAsJson = $TXRConfigData | ConvertTo-Json -Compress:$Compress

        if ($PSCmdlet.ParameterSetName -eq "File") {

            # Check if path exists
            if (Test-Path $Path) {

                if ($PSCmdlet.ShouldProcess($Path, "Write File")) {

                    $DataAsJson | Out-File $Path

                }

            }
            else {

                # Path doesn't exist

                if ($PSCmdlet.ShouldProcess($Path, "Create File")) {

                    # Create placeholder file, including any missing directories
                    # Override ErrorAction preferences because Out-File does not create missing directories and will fail anyway
                    New-Item $Path -ItemType File -Force:$Force -ErrorAction Stop
                    $DataAsJson | Out-File $Path

                }

            }

        }
        else {

            return $DataAsJson

        }

    }

}
