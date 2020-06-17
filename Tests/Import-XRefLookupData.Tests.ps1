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
        Import-XRefLookupData -ApiKey testval -Quiet
        Import-XRefLookupData "$ProjectRoot/Tests/TestDataEmpty.json" -Quiet -ErrorVariable TestErrs -WarningVariable TestWarns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        $TestErrs.Count | Should -Be 3
        $TestWarns.Count | Should -Be 1
    }
}

Describe "Results object" {
    BeforeAll {
        Clear-XRefLookupData -RemoveAll -Force
        $Results = Import-XRefLookupData "$ProjectRoot/Tests/TestData.json" -PassThru -Quiet
    }
    Context "Valid data" {
        It "Results object is correct type" {
            $Results | Should -BeOfType "StreamXRef.ImportResults"
        }
        It "All counters are in results and of correct type" {
            $Results.User | Should -BeOfType "StreamXRef.ImportCounter"
            $Results.Clip | Should -BeOfType "StreamXRef.ImportCounter"
            $Results.Video | Should -BeOfType "StreamXRef.ImportCounter"
        }
        It "Imported counts are correct" {
            $Results.User.Imported | Should -Be 3
            $Results.Clip.Imported | Should -Be 2
            $Results.Video.Imported | Should -Be 2
        }
        It "Total counts are correct" {
            $Results.User.Total | Should -Be 3
            $Results.Clip.Total | Should -Be 2
            $Results.Video.Total | Should -Be 2
        }
        It "ToString method override works" {
            "$($Results.User)" | Should -Be "Imported: 3, Skipped: 0, Error: 0, Total: 3"
            "$($Results.Clip)" | Should -Be "Imported: 2, Skipped: 0, Error: 0, Total: 2"
            "$($Results.Video)" | Should -Be "Imported: 2, Skipped: 0, Error: 0, Total: 2"
        }
        It "All___ properties work" {
            $Results.AllImported | Should -Be 7
            $Results.AllSkipped | Should -Be 0
            $Results.AllError | Should -Be 0
            $Results.AllTotal | Should -Be 7
        }
    }
    Context "Duplicate data" {
        It "Skip duplicate data" {
            # Do not use Clear here because this is testing for duplicate data
            $Results = Import-XRefLookupData "$ProjectRoot/Tests/TestData.json" -PassThru -Quiet -Force

            $Results.User.Imported | Should -Be 0
            $Results.User.Skipped | Should -Be 3
            $Results.Clip.Imported | Should -Be 0
            $Results.Clip.Skipped | Should -Be 2
            $Results.Video.Imported | Should -Be 0
            $Results.Video.Skipped | Should -Be 2
        }
    }
    Context "Invalid data" {
        BeforeAll {
            Clear-XRefLookupData -RemoveAll -Force
            $Results = Import-XRefLookupData "$ProjectRoot/Tests/TestDataInvalid.json" -PassThru -Quiet -ErrorAction SilentlyContinue
        }
        It "Counts bad user entries" {
            $Results.User.Imported | Should -Be 2
            $Results.User.Error | Should -Be 1
        }
        It "Counts bad clip entries" {
            $Results.Clip.Imported | Should -Be 1
            $Results.Clip.Error | Should -Be 2
        }
        It "Counts bad video entries" {
            $Results.Video.Imported | Should -Be 2
            $Results.Video.Error | Should -Be 2
        }
    }
}
