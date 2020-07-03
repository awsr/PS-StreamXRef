#.ExternalHelp StreamXRef-help.xml
function Clear-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High", DefaultParameterSetName = "All")]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [switch]$RemoveAll,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$ApiKey,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$User,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$Clip,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$Video,

        [Parameter(ParameterSetName = "Selection")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -gt 0 })]
        [Alias("Keep")]
        [int]$DaysToKeep,

        [Parameter()]
        [switch]$Force
    )

    Begin {

        if (-not (Test-Path Variable:Script:TwitchData)) {

            throw "Missing required internal resources. Ensure module was loaded correctly."

        }

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

            if ($PSBoundParameters.ContainsKey("DaysToKeep")) {

                $Cutoff = [datetime]::UtcNow - (New-TimeSpan -Days $DaysToKeep)

                if ($Clip) {

                    if ($PSCmdlet.ShouldProcess("Clip lookup data", "Trim entries")) {

                        $PreviousCount = $script:TwitchData:ClipInfoCache.Count

                        # Store separately to avoid enumeration errors
                        [string[]]$PurgeList = $script:TwitchData.ClipInfoCache.GetEnumerator() |
                        Where-Object { $_.Value.Created -lt $Cutoff } | Select-Object -ExpandProperty Key

                        [void]($PurgeList | ForEach-Object { $script:TwitchData.ClipInfoCache.Remove($_) })

                        # Getting the count this way in case removing an entry somehow fails
                        Write-Verbose "(Clip) Data entries removed: $($PreviousCount - $script:TwitchData.ClipInfoCache.Count)"

                    }

                }

                if ($Video) {

                    if ($PSCmdlet.ShouldProcess("Video lookup data", "Trim entries")) {

                        $PreviousCount = $script:TwitchData.VideoInfoCache.Count

                        # Store separately to avoid enumeration errors
                        [string[]]$PurgeList = $script:TwitchData.VideoInfoCache.GetEnumerator() |
                            Where-Object { $_.Value -lt $Cutoff } | Select-Object -ExpandProperty Key

                        [void]($PurgeList | ForEach-Object { $script:TwitchData.VideoInfoCache.Remove($_) })

                        # Getting the count this way in case removing an entry somehow fails
                        Write-Verbose "(Video) Data entries removed: $($PreviousCount - $script:TwitchData.VideoInfoCache.Count)"

                    }

                }

            }
            else {

                # Clear all entries

                if ($Clip) {

                    if ($PSCmdlet.ShouldProcess("Clip lookup data", "Delete entries")) {

                        $script:TwitchData.ClipInfoCache.Clear()
                        Write-Verbose "(Clip) Data cleared"

                    }

                }

                if ($Video) {

                    if ($PSCmdlet.ShouldProcess("Video lookup data", "Delete entries")) {

                        $script:TwitchData.VideoInfoCache.Clear()
                        Write-Verbose "(Video) Data cleared"

                    }

                }

            }

        }

    }

}
