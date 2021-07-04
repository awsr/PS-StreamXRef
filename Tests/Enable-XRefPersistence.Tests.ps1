#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.2.2' }

Describe "Persistence functionality" {
    BeforeAll {
        Get-Module StreamXRef | Remove-Module
        $ProjectRoot = Split-Path -Parent $PSScriptRoot

        # Use Pester automatic variable $TestDrive for temporary location
        # This is currently the only test script that is set up in a way that works with it
        $Env:XRefPersistPath = Join-Path $TestDrive "StreamXRef/datacache.json"

        Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force
    }
    AfterAll {
        Disable-XRefPersistence -Quiet -Remove
        $Env:XRefPersistPath = $null
    }

    Context "Standalone" {
        It "Creates event subscriber" {
            Enable-XRefPersistence -Quiet
            Get-EventSubscriber XRefNewDataAdded | Should -HaveCount 1
        }

        It "Creates placeholder file on first enable" {
            Test-Path $Env:XRefPersistPath | Should -BeTrue
        }
    }

    Context "Automatic" {
        It "Enables persistence on module load" {
            Import-XRefData -ApiKey "TestValue" -Quiet -Persist
            Get-Module StreamXRef | Remove-Module

            Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force

            InModuleScope StreamXRef {
                $PersistEnabled | Should -BeTrue
                $TwitchData.ApiKey | Should -Be "TestValue"
            }
        }
    }

    Context "Formatting" {
        BeforeAll {
            Disable-XRefPersistence -Quiet -Remove
            Clear-XRefData -RemoveAll
            Import-XRefData "$ProjectRoot/Tests/TestDataCompressedMapping.json" -Quiet
        }

        It "No special formatting options" {
            Enable-XRefPersistence -Force -Quiet
            $CheckContent = Get-Content $Env:XRefPersistPath -Raw
            $CheckData = $CheckContent | ConvertFrom-Json

            $CheckContent | Should -Match " "
            $CheckData.config._persist | Should -Be 0

            $MappingCount = 0
            $CheckData.ClipInfoCache.ForEach({$MappingCount += $_.mapping.Count})
            $MappingCount | Should -Be 1
        }

        It "Compress formatting option" {
            Enable-XRefPersistence -Compress -Force -Quiet
            $CheckContent = Get-Content $Env:XRefPersistPath -Raw
            $CheckData = $CheckContent | ConvertFrom-Json

            $CheckContent | Should -Not -Match " " # No whitespace when compressed
            $CheckData.config._persist | Should -Be 1

            $MappingCount = 0
            $CheckData.ClipInfoCache.ForEach({$MappingCount += $_.mapping.Count})
            $MappingCount | Should -Be 1
        }

        It "NoMapping formatting option" {
            Enable-XRefPersistence -ExcludeClipMapping -Force -Quiet
            $CheckContent = Get-Content $Env:XRefPersistPath -Raw
            $CheckData = $CheckContent | ConvertFrom-Json

            $CheckContent | Should -Match " "
            $CheckData.config._persist | Should -Be 2

            $MappingCount = 0
            $CheckData.ClipInfoCache.ForEach({$MappingCount += $_.mapping.Count})
            $MappingCount | Should -Be 0
        }

        It "Both formatting options" {
            Enable-XRefPersistence -Compress -ExcludeClipMapping -Force -Quiet
            $CheckContent = Get-Content $Env:XRefPersistPath -Raw
            $CheckData = $CheckContent | ConvertFrom-Json

            $CheckContent | Should -Not -Match " " # No whitespace when compressed
            $CheckData.config._persist | Should -Be 3

            $MappingCount = 0
            $CheckData.ClipInfoCache.ForEach({$MappingCount += $_.mapping.Count})
            $MappingCount | Should -Be 0
        }
    }
}
