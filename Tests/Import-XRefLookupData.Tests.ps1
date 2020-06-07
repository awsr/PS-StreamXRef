#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force -ErrorAction Stop
}

Describe "Import validation" {
    BeforeAll {
        Clear-XRefLookupData -RemoveAll -Force
        Import-XRefLookupData "$ProjectRoot/Tests/TestData.json" -Quiet -Force -ErrorAction Stop
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
