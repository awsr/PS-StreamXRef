#.ExternalHelp StreamXRef-help.xml
function Clear-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High", DefaultParameterSetName = "All")]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [switch]$RemoveAll,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$ApiKey = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$User = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$Clip = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$Video = $false,

        [Parameter(ParameterSetName = "Selection")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -gt 0 })]
        [Alias("Keep")]
        [int]$DaysToKeep,

        [Parameter()]
        [switch]$Force = $false
    )

    Begin {

        if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {

            $ConfirmPreference = "none"

        }

    }

    Process {

        if ($PSCmdlet.ParameterSetName -eq "All" -and $RemoveAll) {

            if ($PSCmdlet.ShouldProcess("All lookup data", "Delete entries")) {

                $script:TwitchData.ApiKey = $null
                $script:TwitchData.UserInfoCache.Clear()
                $script:TwitchData.ClipInfoCache.Clear()
                $script:TwitchData.VideoInfoCache.Clear()

                Write-Verbose "All lookup data cleared"

            }

        }
        elseif ($PSCmdlet.ParameterSetName -eq "Selection") {

            if ($ApiKey) {

                if ($PSCmdlet.ShouldProcess("API key", "Delete")) {

                    $script:TwitchData.ApiKey.Clear()
                    Write-Verbose "(ApiKey) Data cleared"

                }

            }

            if ($User) {

                if ($PSCmdlet.ShouldProcess("User lookup data", "Delete entries")) {

                    $script:TwitchData.UserInfoCache.Clear()
                    Write-Verbose "(User) Data cleared"

                }

            }

            if ($Clip) {

                if ($PSCmdlet.ShouldProcess("Clip lookup data", "Delete entries")) {

                    $script:TwitchData.ClipInfoCache.Clear()
                    Write-Verbose "(Clip) Data cleared"

                }

            }

            if ($Video) {

                if ($PSBoundParameters.ContainsKey("DaysToKeep")) {

                    if ($PSCmdlet.ShouldProcess("Video lookup data", "Trim entries")) {

                        $Cutoff = [datetime]::UtcNow - (New-TimeSpan -Days $DaysToKeep)

                        $PreviousVideoCacheCount = $script:TwitchData.VideoInfoCache.Count

                        [string[]]$PurgeList = $script:TwitchData.VideoInfoCache.GetEnumerator() |
                            Where-Object { $_.Value -lt $Cutoff } | Select-Object -ExpandProperty Key

                        [void]($PurgeList | ForEach-Object { $script:TwitchData.VideoInfoCache.Remove($_) })

                        $EntriesRemoved = $PreviousVideoCacheCount - $script:TwitchData.VideoInfoCache.Count

                        Write-Verbose "(Video) Data entries removed: $EntriesRemoved"

                    }

                }
                else {

                    if ($PSCmdlet.ShouldProcess("Video lookup data", "Delete entries")) {

                        $script:TwitchData.VideoInfoCache.Clear()
                        Write-Verbose "(Video) Data cleared"

                    }

                }

            }

        }

    }

}
