#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force -ErrorAction Stop
}

Describe "Type loading" {
    It "Add types from dll assembly" {
        {Add-Type -Path "$ProjectRoot/Module/typedata/StreamXRefTypes.dll"} | Should -Not -Throw
    }
    It "Add types from source code" {
        {Add-Type -Path "$ProjectRoot/Module/typedata/StreamXRefTypes.cs"} | Should -Not -Throw
    }
    Context "Specific types" {
        It "ImportCounter type exists" {
            [StreamXRef.ImportCounter] | Should -BeOfType "type"
        }
        It "ImportResults type exists" {
            [StreamXRef.ImportResults] | Should -BeOfType "type"
        }
    }
    Context "Custom type members" {
        It "ImportCounter contains all properties" {
            $Properties = [StreamXRef.ImportCounter].DeclaredProperties.Name
            $Properties | Should -Contain Name
            $Properties | Should -Contain Imported
            $Properties | Should -Contain Skipped
            $Properties | Should -Contain Error
            $Properties | Should -Contain Total
        }
        It "ImportResults contains all properties" {
            $Properties = [StreamXRef.ImportResults].DeclaredProperties.Name
            $Properties | Should -Contain AllImported
            $Properties | Should -Contain AllSkipped
            $Properties | Should -Contain AllError
            $Properties | Should -Contain AllTotal
        }
        It "ImportResults contains AddCounter method" {
            [StreamXRef.ImportResults].DeclaredMethods.Name | Should -Contain AddCounter
        }
    }
    Context "Custom type actions" {
        BeforeAll {
            $TestObj = [StreamXRef.ImportCounter]::new("Test")
            $ResultObj = [StreamXRef.ImportResults]::new()
        }
        It "ImportCounter constructor sets name" {
            $TestObj.Name | Should -Be "Test"
        }
        It "ImportCounter.Total sums all counter properties" {
            $TestObj.Imported = 20
            $TestObj.Skipped = 4
            $TestObj.Error = 3
            $TestObj.Total | Should -Be 27
        }
        It "ImportResults.AddCounter(...) adds counter object" {
            $ResultObj.AddCounter("Test1")
            $ResultObj.Keys | Should -Contain "Test1"
        }
    }
}

Describe "Internal function validation" {
    Context "Timestamp conversion" {
        It "Converts strings already in UTC" {
            InModuleScope StreamXRef {
                '2020-06-06T07:09:15Z' | ConvertTo-UtcDateTime | Should -Be ([datetime]::new(2020, 6, 6, 7, 9, 15, [System.DateTimeKind]::Utc))
            }
        }
        It "Converts strings with a time zone offset" {
            InModuleScope StreamXRef {
                '2020-06-06T09:09:15+02:00' | ConvertTo-UtcDateTime | Should -Be ([datetime]::new(2020, 6, 6, 7, 9, 15, [System.DateTimeKind]::Utc))
            }
        }
    }
    Context "URL filtering" {
        It "Removes junk from clip URL" {
            InModuleScope StreamXRef {
                'https://www.twitch.tv/someuser/clip/TestStringPleaseWork?filter=clips&range=7d&sort=time' | Get-LastUrlSegment | Should -Be 'TestStringPleaseWork'
                'https://clips.twitch.tv/TestStringPleaseWork' | Get-LastUrlSegment | Should -Be 'TestStringPleaseWork'
            }
        }
    }
}
