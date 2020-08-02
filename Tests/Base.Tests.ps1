#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.2' }

BeforeAll {
    Get-Module StreamXRef | Remove-Module
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force
}

Describe "Custom type data" {
    BeforeAll {
        # If one "Should" test fails, keep checking the rest in the "It" block
        $PesterPreference = [PesterConfiguration]::Default
        $PesterPreference.Should.ErrorAction = "Continue"
    }
    Context "Constructors" {
        It "ImportCounter can be created" {
            { [StreamXRef.ImportCounter]::new("Test") } | Should -Not -Throw
        }
        It "ImportCounter requires input value" {
            { [StreamXRef.ImportCounter]::new() } | Should -Throw
        }
        It "ImportResults can be created" {
            { [StreamXRef.ImportResults]::new() } | Should -Not -Throw
        }
        It "ClipObject can be created" {
            { [StreamXRef.ClipObject]::new() } | Should -Not -Throw
        }
        It "DataCache can be created" {
            { [StreamXRef.DataCache]::new() } | Should -Not -Throw
        }
    }
    Context "Members" {
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
            $Properties = [StreamXRef.ImportResults].DeclaredMethods.Name

            $Properties | Should -Contain AddCounter
        }
        It "ClipObject contains all properties" {
            $Properties = [StreamXRef.ClipObject].DeclaredProperties.Name

            $Properties | Should -Contain Offset
            $Properties | Should -Contain VideoID
            $Properties | Should -Contain Created
            $Properties | Should -Contain Mapping
        }
        It "DataCache contains all properties" {
            $Properties = [StreamXRef.DataCache].DeclaredProperties.Name

            $Properties | Should -Contain ApiKey
            $Properties | Should -Contain UserInfoCache
            $Properties | Should -Contain ClipInfoCache
            $Properties | Should -Contain VideoInfoCache
        }
        It "DataCache contains GetTotalCount method" {
            $Properties = [StreamXRef.DataCache].DeclaredMethods.Name

            $Properties | Should -Contain GetTotalCount
        }
    }
    Context "Functionality" {
        It "ImportCounter.Total sums all counter properties" {
            $TestObj = [StreamXRef.ImportCounter]::new("Test")
            $TestObj.Imported = 20
            $TestObj.Skipped = 4
            $TestObj.Error = 3

            $TestObj.Total | Should -Be 27
        }
        It "ImportResults.AddCounter(...) adds counter object" {
            $ResultObj = [StreamXRef.ImportResults]::new()
            $ResultObj.AddCounter("Test1")

            $ResultObj.Keys | Should -Contain "Test1"
            $ResultObj["Test1"] | Should -BeOfType "StreamXRef.ImportCounter"
        }
        It "DataCache.GetTotalCount() sums all dictionary counts" {
            $TestCache = [StreamXRef.DataCache]::new()
            $TestCache.UserInfoCache.Add("TestName", 12345678)
            $TestCache.ClipInfoCache.Add("TestClip", [StreamXRef.ClipObject]::new())
            $TestCache.VideoInfoCache.Add(123456789, [datetime]::UtcNow)

            $TestCache.GetTotalCount() | Should -Be 3
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

Describe "System environment" {
    It "Application Data folder can be determined" {
        { [System.Environment]::GetFolderPath("ApplicationData") } | Should -Not -Throw
        [string]::IsNullOrWhiteSpace([System.Environment]::GetFolderPath("ApplicationData")) | Should -BeFalse
    }
}
