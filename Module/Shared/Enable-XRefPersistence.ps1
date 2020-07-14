#.ExternalHelp StreamXRef-help.xml
function Enable-XRefPersistence {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter()]
        [switch]$Quiet
    )

    Process {

        if ($PersistStatus.CanUse) {

            if ($PersistStatus.Enabled) {

                if (-not $Quiet) {
                    Write-Host "StreamXRef persistence is already enabled."
                }
                return

            }
            else {

                # Restore previously-disabled persistence file if it exists
                if (Test-Path "$PersistPath.bak") {

                    Move-Item "$PersistPath.bak" $PersistPath -Force

                    if (-not $Quiet) {
                        Write-Host "Restoring previous StreamXRef persistence data."
                    }

                }

                if (Test-Path $PersistPath) {

                    Import-XRefLookupData -Path $PersistPath -Quiet -Force

                    # Clean up entries older than 60 days (default Twitch retention policy)
                    Clear-XRefLookupData -Name Clip, Video -DaysToKeep 60

                    # Export cleaned data back to persistent storage
                    Export-XRefLookupData -Path $PersistPath -Force

                }
                else {

                    <#  Try creating placeholder here before registering event subscriber so
                        that there's only one error message if the path can't be written to. #>
                    [void] (New-Item -Path $PersistPath -ItemType File -Force -ErrorAction Stop)

                }

                # Suppress writing job info to host when registering
                [void] (Register-EngineEvent -SourceIdentifier XRefNewDataAdded -ErrorAction Stop -Action {
                    Export-XRefLookupData -Path $script:PersistPath -Force
                })

                # Take note of the subscription id (might not be the same as the PSEventJob id)
                $script:PersistStatus.Id = (Get-EventSubscriber -SourceIdentifier XRefNewDataAdded | Select-Object -Last 1).SubscriptionId

                $script:PersistStatus.Enabled = $true

                if (-not $Quiet) {
                    Write-Host -BackgroundColor Black -ForegroundColor Green "StreamXRef persistence enabled."
                }

            }

        }
        else {

            Write-Error "Unable to determine Application Data path"

        }

    }

}
