#.ExternalHelp StreamXRef-help.xml
function Disable-XRefPersistence {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter()]
        [switch]$Quiet,

        [Parameter()]
        [switch]$Remove,

        [Parameter(DontShow)]
        [switch]$_Reset
    )

    Process {
        if ($PersistCanUse) {
            if ($Remove) {
                if (Test-Path "$PersistPath*") {
                    # Delete file (and/or .bak version)
                    Remove-Item "$PersistPath*" -Force
                    if (-not $Quiet) {
                        Write-Host "StreamXRef persistence files deleted."
                    }
                }
                elseif (-not $Quiet) {
                    Write-Host "No StreamXRef persistence files to delete."
                }
            }
            elseif (-not $_Reset -and (Test-Path $PersistPath)) {
                # Add ".bak" to name to prevent auto-loading (except when resetting)
                Move-Item $PersistPath "$PersistPath.bak" -Force
            }

            # Disable persistence subscriber
            if ($PersistId -ne 0) {
                Unregister-Event -SubscriptionId $PersistId

                # Reset value
                $script:PersistId = 0

                if (-not $Quiet) {
                    Write-Host "StreamXRef persistence disabled."
                }
            }

            $script:PersistEnabled = $false
        }
        else {
            Write-Error "Data persistence path is not set."
        }
    }
}
