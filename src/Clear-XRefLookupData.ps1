#.ExternalHelp StreamXRef-help.xml
function Clear-XRefLookupData {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High", DefaultParameterSetName = "All")]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [switch]$ResetAll,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$ApiKey = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$UserInfoCache = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$ClipInfoCache = $false,

        [Parameter(ParameterSetName = "Selection")]
        [switch]$VideoInfoCache = $false,

        [Parameter()]
        [switch]$Force = $false
    )

    DynamicParam {
        # If VideoInfoCache is specified, add DaysToKeep parameter
        if ($PSBoundParameters.ContainsKey("VideoInfoCache")) {
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

        if ($Force -and -not ($PSBoundParameters.ContainsKey("Confirm") -and $Confirm)) {

            $ConfirmPreference = "none"

        }

    }
    
    Process {

        if ($PSCmdlet.ParameterSetName -eq "All" -and $ResetAll) {

            if ($PSCmdlet.ShouldProcess("All cached lookup data", "Clear")) {

                $script:TwitchData.ApiKey = $null
                $script:TwitchData.UserInfoCache.Clear()
                $script:TwitchData.ClipInfoCache.Clear()
                $script:TwitchData.VideoInfoCache.Clear()

                Write-Verbose "All lookup data cleared"

            }

        }
        elseif ($PSCmdlet.ParameterSetName -eq "Selection") {

            if ($ApiKey) {

                if ($PSCmdlet.ShouldProcess("API key", "Clear")) {

                    $script:TwitchData.ApiKey.Clear()
                    Write-Verbose "(ApiKey) Data cleared"

                }

            }

            if ($UserInfoCache) {

                if ($PSCmdlet.ShouldProcess("User ID lookup data", "Clear")) {

                    $script:TwitchData.UserInfoCache.Clear()
                    Write-Verbose "(UserInfoCache) data cleared"

                }

            }

            if ($ClipInfoCache) {

                if ($PSCmdlet.ShouldProcess("Clip info lookup data", "Clear")) {

                    $script:TwitchData.ClipInfoCache.Clear()
                    Write-Verbose "(ClipInfoCache) Data cleared"

                }

            }

            if ($VideoInfoCache) {

                if ($PSBoundParameters.ContainsKey("DaysToKeep")) {

                    if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Trim")) {

                        $Cutoff = [datetime]::UtcNow - (New-TimeSpan -Days $DaysToKeep)
    
                        $PreviousVideoCacheCount = $script:TwitchData.VideoInfoCache.Count
        
                        [string[]]$PurgeList = $script:TwitchData.VideoInfoCache.GetEnumerator() |
                            Where-Object { $_.Value -lt $Cutoff } | Select-Object -ExpandProperty Key
            
                        $PurgeList | ForEach-Object { $script:TwitchData.VideoInfoCache.Remove($_) } | Out-Null
            
                        $EntriesRemoved = $PreviousVideoCacheCount - $script:TwitchData.VideoInfoCache.Count
            
                        Write-Verbose "(VideoInfoCache) Data entries removed: $EntriesRemoved"

                    }

                }
                else {
    
                    if ($PSCmdlet.ShouldProcess("Video timestamp lookup data", "Delete")) {
    
                        $script:TwitchData.VideoInfoCache.Clear()
                        Write-Verbose "(VideoInfoCache) Data cleared"
    
                    }
    
                }

            }

        }

    }

}
