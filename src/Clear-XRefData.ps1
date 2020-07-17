#.ExternalHelp StreamXRef-help.xml
function Clear-XRefData {
    [CmdletBinding(DefaultParameterSetName = "Selection")]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Selection")]
        [ValidateSet("ApiKey", "User", "Clip", "Video")]
        [string[]]$Name,

        [Parameter(Position = 1, ParameterSetName = "Selection")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -gt 0 })]
        [Alias("Keep")]
        [int]$DaysToKeep,

        [Parameter(ParameterSetName = "All")]
        [switch]$RemoveAll
    )

    Begin {

        if (-not (Test-Path Variable:Script:TwitchData)) {

            throw "Missing required internal resources. Ensure module was loaded correctly."

        }

    }

    Process {

        if ($RemoveAll) {

            $script:TwitchData.ApiKey = $null
            $script:TwitchData.UserInfoCache.Clear()
            $script:TwitchData.ClipInfoCache.Clear()
            $script:TwitchData.VideoInfoCache.Clear()

            Write-Verbose "All lookup data cleared"

        }
        else {

            if ($Name -icontains "ApiKey") {

                $script:TwitchData.ApiKey.Clear()
                Write-Verbose "(ApiKey) Data cleared"

            }

            if ($Name -icontains "User") {

                $script:TwitchData.UserInfoCache.Clear()
                Write-Verbose "(User) Data cleared"

            }

            if ($PSBoundParameters.ContainsKey("DaysToKeep")) {

                $Cutoff = [datetime]::UtcNow - (New-TimeSpan -Days $DaysToKeep)

                if ($Name -icontains "Clip") {

                    $PreviousCount = $script:TwitchData.ClipInfoCache.Count

                    # Store separately to avoid enumeration errors
                    [string[]]$PurgeList = $script:TwitchData.ClipInfoCache.GetEnumerator() |
                    Where-Object { $_.Value.Created -lt $Cutoff } | Select-Object -ExpandProperty Key

                    [void]($PurgeList | ForEach-Object { $script:TwitchData.ClipInfoCache.Remove($_) })

                    # Getting the count this way in case removing an entry somehow fails
                    Write-Verbose "(Clip) Data entries removed: $($PreviousCount - $script:TwitchData.ClipInfoCache.Count)"

                }

                if ($Name -icontains "Video") {

                    $PreviousCount = $script:TwitchData.VideoInfoCache.Count

                    # Store separately to avoid enumeration errors
                    [string[]]$PurgeList = $script:TwitchData.VideoInfoCache.GetEnumerator() |
                        Where-Object { $_.Value -lt $Cutoff } | Select-Object -ExpandProperty Key

                    [void]($PurgeList | ForEach-Object { $script:TwitchData.VideoInfoCache.Remove($_) })

                    # Getting the count this way in case removing an entry somehow fails
                    Write-Verbose "(Video) Data entries removed: $($PreviousCount - $script:TwitchData.VideoInfoCache.Count)"

                }

            }
            else {

                # Clear all entries

                if ($Name -icontains "Clip") {

                    $script:TwitchData.ClipInfoCache.Clear()
                    Write-Verbose "(Clip) Data cleared"

                }

                if ($Name -icontains "Video") {

                    $script:TwitchData.VideoInfoCache.Clear()
                    Write-Verbose "(Video) Data cleared"

                }

            }

        }

    }

}
