
function Clear-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low", DefaultParameterSetName = "All")]
    Param(
        [Parameter(ParameterSetName = "All")]
        [switch]$ResetAll = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$ApiKey = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$UserIdCache = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$ClipInfoCache = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$VideoStartCache = $false
    )

    DynamicParam {
        # If VideoStartCache is specified, add DaysToKeep parameter
        if ($PSBoundParameters.ContainsKey("VideoStartCache")) {
            $psnAttr = [System.Management.Automation.ParameterAttribute]::new()
            $psnAttr.ParameterSetName = "Selection"
            $vnnoeAttr = [System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new()
            $valScriptAttr = [System.Management.Automation.ValidateScriptAttribute]::new({ $_ -ge 0 })
            $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $attributeCollection.Add($psnAttr)
            $attributeCollection.Add($vnnoeAttr)
            $attributeCollection.Add($valScriptAttr)
    
            $dynParam2Keep = [System.Management.Automation.RuntimeDefinedParameter]::new("DaysToKeep", [int], $attributeCollection)
    
            $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
            $paramDictionary.Add("DaysToKeep", $dynParam2Keep)
            return $paramDictionary
        }
    }

    Begin {

        if (-not (Test-Path Variable:Script:TwitchData) -and $ResetAll) {

            Write-Verbose "No data to clear. Initializing empty variable instead."

            Initialize-LookupCache -ErrorAction Stop

            return

        }

    }
    
    Process {

        if ($ResetAll) {

            if ($PSCmdlet.ShouldProcess("All cached lookup data", "Delete")) {

                $script:TwitchData.ApiKey = $null
                $script:TwitchData.UserIdCache.Clear()
                $script:TwitchData.ClipInfoCache.Clear()
                $script:TwitchData.VideoStartCache.Clear()

            }

        }
        elseif ($PSCmdlet.ParameterSetName -eq "Selection") {

            if ($ApiKey) {

                if ($PSCmdlet.ShouldProcess("ApiKey", "Delete")) {

                    $script:TwitchData.ApiKey.Clear()
                    Write-Verbose "API key cleared"

                }

            }

            if ($UserIdCache) {

                if ($PSCmdlet.ShouldProcess("User ID lookup data", "Delete")) {

                    $script:TwitchData.UserIdCache.Clear()
                    Write-Verbose "User ID cache entries cleared"

                }

            }

            if ($ClipInfoCache) {

                if ($PSCmdlet.ShouldProcess("Clip info lookup data", "Delete")) {

                    $script:TwitchData.ClipInfoCache.Clear()
                    Write-Verbose "Clip cache entries cleared"

                }

            }

            if ($VideoStartCache) {

                if ($PSBoundParameters.ContainsKey("DaysToKeep")) {

                    if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Trim")) {

                        $Cutoff = [datetime]::UtcNow - (New-TimeSpan -Days $DaysToKeep)
    
                        $PreviousVideoCacheCount = $script:TwitchData.VideoStartCache.Count
        
                        [string[]]$PurgeList = $script:TwitchData.VideoStartCache.GetEnumerator() |
                            Where-Object { $_.Value -lt $Cutoff } | Select-Object -ExpandProperty Key
            
                        $PurgeList | ForEach-Object { $script:TwitchData.VideoStartCache.Remove($_) } | Out-Null
            
                        $EntriesRemoved = $PreviousVideoCacheCount - $script:TwitchData.VideoStartCache.Count
            
                        Write-Host "Video cache entries removed: $EntriesRemoved"

                    }

                }
                else {
    
                    if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Delete")) {
    
                        $script:TwitchData.VideoStartCache.Clear()
                        Write-Verbose "Video cache entries cleared"
    
                    }
    
                }

            }

        }

    }

}
