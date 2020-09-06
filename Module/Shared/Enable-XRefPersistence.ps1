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
        [switch]$Quiet
    )

    Process {
        # Check for persistance path override (except during import, where this was already done)
        if ((Test-Path Env:XRefPersistPath) -and $null -ne $Env:XRefPersistPath -and $MyInvocation.PSCommandPath -notlike "*StreamXRef.psm1") {
            if ((Test-Path $Env:XRefPersistPath -IsValid) -and $Env:XRefPersistPath -like "*.json") {
                $script:PersistPath = $Env:XRefPersistPath
                $script:PersistCanUse = $true
            }
            else {
                Write-Error "XRefPersistPath environment variable must specify a .json file"
            }
        }

        if ($PersistCanUse) {
            if ($PersistEnabled) {
                # Disable persistance before recreating with new settings
                Disable-XRefPersistence -Quiet
            }
            elseif (Test-Path "$PersistPath.bak") {
                # Restore previously-disabled persistence file
                Move-Item "$PersistPath.bak" $PersistPath -Force
                if (-not $Quiet) {
                    Write-Host "Restoring previous StreamXRef persistence data."
                }
            }

            if (Test-Path $PersistPath) {
                # ===== Import Data =====
                Import-XRefData -Path $PersistPath -Quiet -Force
                # PersistFormatting is now set from imported data if it was specified

                # Clean up entries older than 60 days (default Twitch retention policy)
                Clear-XRefData -Name Clip, Video -DaysToKeep 60
            }
            else {
                <#  Try creating placeholder here before registering event subscriber so
                    that there's only one error message if the path can't be written to. #>
                [void] (New-Item -Path $PersistPath -ItemType File -Force -ErrorAction Stop)
            }

            # Update PersistFormatting if not called during module import
            if ($MyInvocation.PSCommandPath -notlike "*StreamXRef.psm1") {
                $script:PersistFormatting = [SXRPersistFormat]::None
                if ($Compress) {
                    $script:PersistFormatting += [SXRPersistFormat]::Compress
                }
                if ($ExcludeClipMapping) {
                    $script:PersistFormatting += [SXRPersistFormat]::NoMapping
                }
            }

            # Export data to persistent storage
            Export-XRefData -Path $PersistPath -_PersistConfig -Force -WarningAction SilentlyContinue

            # Populate path for event scriptblock in advance
            $EventAction = [scriptblock]::Create("Export-XRefData -Path $script:PersistPath -_PersistConfig -Force")

            # Suppress writing job info to host when registering
            [void] (Register-EngineEvent -SourceIdentifier XRefNewDataAdded -ErrorAction Stop -Action $EventAction)

            # Take note of the subscription id (might not be the same as the PSEventJob id)
            $script:PersistId = (Get-EventSubscriber -SourceIdentifier XRefNewDataAdded | Select-Object -Last 1).SubscriptionId

            $script:PersistEnabled = $true

            if (-not $Quiet) {
                Write-Host -BackgroundColor Black -ForegroundColor Green "StreamXRef persistence enabled."
            }
        }
        else {
            Write-Error "Unable to determine Application Data path"
        }
    }
}
