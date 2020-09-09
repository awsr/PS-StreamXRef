#.ExternalHelp StreamXRef-help.xml
function Enable-XRefPersistence {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter()]
        [switch]$Compress,

        [Parameter()]
        [Alias("NoMapping", "ECM")]
        [switch]$ExcludeClipMapping,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Quiet
    )

    Process {
        $FormatOptions = [SXRPersistFormat]::Standard
        if ($Compress) {
            $FormatOptions += [SXRPersistFormat]::Compress
        }
        if ($ExcludeClipMapping) {
            $FormatOptions += [SXRPersistFormat]::NoMapping
        }

        if ($PersistCanUse -and $PersistEnabled) {
            if ($Force) {
                # Disable old persistance before recreating with new settings
                Disable-XRefPersistence -Quiet -_Reset
            }
            else {
                if (-not $Quiet) {
                    Write-Host "StreamXRef persistence is already enabled."
                    Write-Host "To update formatting options, run with -Force."
                }
                return
            }
        }

        if ($PSCmdlet.MyInvocation -notlike "*StreamXRef.psm1") {
            # Get persistence path to use
            Get-PersistPath
        }

        if ($PersistCanUse) {
            if ((Test-Path "$PersistPath.bak") -and -not (Test-Path $PersistPath)) {
                # Restore previously-disabled persistence file
                if (-not $Quiet) {
                    Write-Host "Resuming StreamXRef persistence."
                }
                Move-Item "$PersistPath.bak" $PersistPath -Force -ErrorAction Stop
            }

            if (Test-Path $PersistPath) {
                Import-XRefData -Path $PersistPath -Quiet -Force -WarningAction SilentlyContinue
                # PersistFormatting is now set from imported data if it was specified

                # Clean up entries older than 60 days (default Twitch retention policy)
                Clear-XRefData -Name Clip, Video -DaysToKeep 60

                if ($Force) {
                    # Override imported persistence formatting with new values
                    $script:PersistFormatting = $FormatOptions
                }

                # Export cleaned data back to persistent storage
                Export-XRefData -Path $PersistPath -_PersistConfig -Force -WarningAction SilentlyContinue
            }
            else {
                # Create placeholder file to ensure path can be written to
                [void] (New-Item -Path $PersistPath -ItemType File -Force -ErrorAction Stop)

                # Force parameter isn't needed here since there's nothing to override
                $script:PersistFormatting = $FormatOptions

                Export-XRefData -Path $PersistPath -_PersistConfig -Force -WarningAction SilentlyContinue
            }

            # Populate path for event scriptblock in advance
            $EventAction = [scriptblock]::Create("Export-XRefData -Path $script:PersistPath -_PersistConfig -Force")

            # Suppress writing job info to host when registering
            [void] (Register-EngineEvent -SourceIdentifier XRefNewDataAdded -ErrorAction Stop -Action $EventAction)

            # Take note of the subscription id (might not be the same as the PSEventJob id)
            $script:PersistId = (Get-EventSubscriber -SourceIdentifier XRefNewDataAdded | Select-Object -Last 1).SubscriptionId

            $script:PersistEnabled = $true

            if (-not $Quiet) {
                Write-Host -BackgroundColor Black -ForegroundColor Green "StreamXRef persistence enabled ($script:PersistFormatting)"
            }
        }
    }
}
