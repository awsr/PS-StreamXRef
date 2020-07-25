#.ExternalHelp StreamXRef-help.xml
function Enable-XRefPersistence {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter()]
        [switch]$Quiet
    )

    Process {

        if ($PersistCanUse) {

            if ($PersistEnabled) {

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

                    Import-XRefData -Path $PersistPath -Quiet -Force

                    # Clean up entries older than 60 days (default Twitch retention policy)
                    Clear-XRefData -Name Clip, Video -DaysToKeep 60

                    # Export cleaned data back to persistent storage
                    Export-XRefData -Path $PersistPath -Force -WarningAction SilentlyContinue

                }
                else {

                    <#  Try creating placeholder here before registering event subscriber so
                        that there's only one error message if the path can't be written to. #>
                    [void] (New-Item -Path $PersistPath -ItemType File -Force -ErrorAction Stop)
                    Export-XRefData -Path $PersistPath -Force -WarningAction Ignore

                }

                # Populate path for event scriptblock in advance
                $EventAction = [scriptblock]::Create("Export-XRefData -Path $script:PersistPath -Force")

                # Suppress writing job info to host when registering
                [void] (Register-EngineEvent -SourceIdentifier XRefNewDataAdded -ErrorAction Stop -Action $EventAction)

                # Take note of the subscription id (might not be the same as the PSEventJob id)
                $script:PersistId = (Get-EventSubscriber -SourceIdentifier XRefNewDataAdded | Select-Object -Last 1).SubscriptionId

                $script:PersistEnabled = $true

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
