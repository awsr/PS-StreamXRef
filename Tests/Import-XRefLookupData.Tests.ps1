#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force -ErrorAction Stop
}

Describe "Import validation" {
    BeforeEach {
        Clear-XRefLookupData -RemoveAll -Force
    }
    It "Times are in UTC" {
        Import-XRefLookupData "$ProjectRoot/Tests/TestData.json" -Quiet -Force -ErrorAction Stop
        InModuleScope StreamXRef {
            $TwitchData.ClipInfoCache.GetEnumerator() | ForEach-Object {
                $_.Value.Created.Kind | Should -Be Utc
            }
            $TwitchData.VideoInfoCache.GetEnumerator() | ForEach-Object {
                $_.Value.Kind | Should -Be Utc
            }
        }
    }
    It "Writes errors for missing data" {
        Import-XRefLookupData "$ProjectRoot/Tests/TestDataEmpty.json" -Quiet -ErrorVariable TestErrs -ErrorAction SilentlyContinue
        $TestErrs.Count | Should -Be 4
    }
    It "Does not write error for missing API key when one already exists" {
        Import-XRefLookupData -ApiKey testval
        Import-XRefLookupData "$ProjectRoot/Tests/TestDataEmpty.json" -Quiet -ErrorVariable TestErrs -WarningVariable TestWarns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        $TestErrs.Count | Should -Be 3
        $TestWarns.Count | Should -Be 1
    }
}

Describe "Results object" {
    Context "Valid data" {
        BeforeAll {
            Clear-XRefLookupData -RemoveAll -Force
            $Results = Import-XRefLookupData "$ProjectRoot/Tests/TestData.json" -PassThru -Quiet
        }
        It "Shortcut parameters point to correct data" {
            $Results.User.Name | Should -Be "User"
            $Results.Clip.Name | Should -Be "Clip"
            $Results.Video.Name | Should -Be "Video"
        }
        It "Imported counts are correct" {
            $Results.User.Imported | Should -Be 3
            $Results.Clip.Imported | Should -Be 2
            $Results.Video.Imported | Should -Be 2
        }
    }
    Context "Duplicate data" {
        BeforeAll {
            $Results = Import-XRefLookupData "$ProjectRoot/Tests/TestData.json" -PassThru -Quiet -Force
        }
        It "Ignore duplicate data" {
            $Results.User.Imported | Should -Be 0
            $Results.User.Ignored | Should -Be 3
            $Results.Clip.Imported | Should -Be 0
            $Results.Clip.Ignored | Should -Be 2
            $Results.Video.Imported | Should -Be 0
            $Results.Video.Ignored | Should -Be 2
        }
    }
}
