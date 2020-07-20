#.ExternalHelp StreamXRef-help.xml
function Disable-XRefPersistence {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter()]
        [switch]$Quiet,

        [Parameter()]
        [switch]$Remove
    )

    Process {

        if ($PersistCanUse) {

            if ($Remove) {

                if (Test-Path $PersistPath*) {

                    # Delete file (and/or .bak version)
                    Remove-Item "$PersistPath*" -Force

                    if (-not $Quiet) {
                        Write-Host "StreamXRef persistence files deleted."
                    }

                }
                elseif (-not $Quiet) {

                    Write-Host "No XtreamXRef persistence files to delete."

                }

            }
            else {

                # Add ".bak" to name to prevent auto-loading
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

            Write-Error "Unable to determine Application Data path"

        }

    }

}
