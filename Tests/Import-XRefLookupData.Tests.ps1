#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ModulePath "Module/StreamXRef.psd1"
    Import-Module $ModulePath -Force -ErrorAction Stop
}

Describe "Import validation" {
    BeforeAll {
        Clear-XRefLookupData -RemoveAll -Force
        Import-XRefLookupData ./TestData.json -Quiet -Force -ErrorAction Stop
    }
    It "Times are in UTC" {
        InModuleScope StreamXRef {
            $TwitchData.ClipInfoCache.GetEnumerator() | ForEach-Object {
                $_.Value.Created.Kind | Should -Be Utc
            }
            $TwitchData.VideoInfoCache.GetEnumerator() | ForEach-Object {
                $_.Value.Kind | Should -Be Utc
            }
        }
    }
}
