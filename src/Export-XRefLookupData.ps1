
function Export-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium", DefaultParameterSetName = "Object")]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "File", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -IsValid })]
        [string]$Path,

        [Parameter(ParameterSetName = "File")]
        [switch]$Force = $false,

        [Parameter(ParameterSetName = "Object")]
        [Parameter(ParameterSetName = "File")]
        [switch]$Compress = $false
    )

    Begin {

        if (-not (Test-Path Variable:Script:TwitchData)) {

            Write-Warning "No data to export."
            return

        }

        if ($PSCmdlet.ParameterSetName -eq "File") {

            $PathParent = Split-Path $Path -Parent

            if ($Force) {

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

        # Bundle data together for convertign to Json
        $TXRConfigData = [pscustomobject]@{
            ApiKey          = $script:TwitchData.ApiKey
            UserIdCache     = $script:TwitchData.UserIdCache
            ClipInfoCache   = $script:TwitchData.ClipInfoCache
            VideoStartCache = $ConvertedVideoStartCache
        }

        # Save Json string
        $DataAsJson = $TXRConfigData | ConvertTo-Json -Compress:$Compress

        if ($PSCmdlet.ParameterSetName -eq "File") {

            # Check if path directory exists and create if it doesn't
            if (-not (Test-Path $PathParent)) {

                if ($PSCmdlet.ShouldProcess($ParentPath, "Create Directory")) {

                    New-Item $PathParent -ItemType Directory -ErrorAction Stop
    
                }
    
            }

            # Write file
            if ($PSCmdlet.ShouldProcess($Path, "Write File")) {

                $DataAsJson | Out-File $Path

            }

        }
        else {

            return $DataAsJson

        }

    }

}
