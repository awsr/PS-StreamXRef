#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force -ErrorAction Stop
}

Describe "Export validation" {
    BeforeAll {
        $TempPath = "$ProjectRoot/temp"
        if (-not (Test-Path $TempPath -PathType Container)) {
            New-Item -Path $TempPath -ItemType Directory -Force -ErrorAction Stop
        }
        Clear-XRefLookupData -RemoveAll -Force
        Import-XRefLookupData "$ProjectRoot/Tests/TestData.json" -Quiet -Force -ErrorAction Stop
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

        Export-XRefLookupData -Path "$TempPath/CheckData.json" -Compress -Force
        $CheckData = (Get-Content -Path "$TempPath/CheckData.json").Trim()

        $CheckData | Should -Be $KnownGood
    }
}
