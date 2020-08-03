#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.2' }

BeforeAll {
    Get-Module StreamXRef | Remove-Module
    $ProjectRoot = Split-Path -Parent $PSScriptRoot

    # Use Pester automatic variable $TestDrive for temporary location
    $Env:XRefPersistPath = Join-Path $TestDrive "StreamXRef/datacache.json"

    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force
}

Describe "Export validation" {
    BeforeAll {
        $TempPath = "$ProjectRoot/temp"
        if (-not (Test-Path $TempPath -PathType Container)) {
            New-Item -Path $TempPath -ItemType Directory -Force -ErrorAction Stop
        }
        Clear-XRefData -RemoveAll
        Import-XRefData "$ProjectRoot/Tests/TestData.json" -Quiet -Force -ErrorAction Stop
    }
    AfterEach {
        Remove-Item "$TempPath/*.*" -Recurse -Force
    }
    AfterAll {
        Remove-Item $TempPath -Force
    }

    It "Exports correct JSON data" {
        # Store known good data and trim newline characters since it doesn't matter if those are different
        $KnownGood = (Get-Content -Path "$ProjectRoot/Tests/TestDataCompressed.json").Trim()

        Export-XRefData -Path "$TempPath/CheckData.json" -Compress -Force
        $CheckData = (Get-Content -Path "$TempPath/CheckData.json").Trim()

        $CheckData | Should -Be $KnownGood
    }
}
