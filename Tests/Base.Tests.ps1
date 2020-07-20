#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.2' }

BeforeAll {
    Get-Module StreamXRef | Remove-Module
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force
}

Describe "Custom type data" {
    Context "Constructors" {
        It "ImportCounter can be created" {
            {[StreamXRef.ImportCounter]::new("Test")} | Should -Not -Throw
        }
        It "ImportCounter requires input value" {
            {[StreamXRef.ImportCounter]::new()} | Should -Throw
        }
        It "ImportResults can be created" {
            {[StreamXRef.ImportResults]::new()} | Should -Not -Throw
        }
        It "ClipObject can be created" {
            {[StreamXRef.ClipObject]::new()} | Should -Not -Throw
        }
        It "DataCache can be created" {
            {[StreamXRef.DataCache]::new()} | Should -Not -Throw
        }
    }
    Context "Members" {
        It "ImportCounter contains all properties" {
            [StreamXRef.ImportCounter].DeclaredProperties.Name | ForEach-Object {
                $_ | Should -BeIn Name, Imported, Skipped, Error, Total
            }
        }
        It "ImportResults contains all properties" {
            [StreamXRef.ImportResults].DeclaredProperties.Name | ForEach-Object {
                $_ | Should -BeIn AllImported, AllSkipped, AllError, AllTotal
            }
        }
        It "ImportResults contains AddCounter method" {
            [StreamXRef.ImportResults].DeclaredMethods.Name | Should -Contain AddCounter
        }
        It "ClipObject contains all properties" {
            [StreamXRef.ClipObject].DeclaredProperties.Name | ForEach-Object {
                $_ | Should -BeIn Offset, VideoID, Created, Mapping
            }
        }
        It "DataCache contains all properties" {
            [StreamXRef.DataCache].DeclaredProperties.Name | ForEach-Object {
                $_ | Should -BeIn ApiKey, UserInfoCache, ClipInfoCache, VideoInfoCache
            }
        }
        It "DataCache contains GetTotalCount method" {
            [StreamXRef.DataCache].DeclaredMethods.Name | Should -Contain GetTotalCount
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
