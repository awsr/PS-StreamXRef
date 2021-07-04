#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.2.2' }

BeforeAll {
    Get-Module StreamXRef | Remove-Module
    $ProjectRoot = Split-Path -Parent $PSScriptRoot

    # Manual setup for temporary path
    $Env:XRefPersistPath = Join-Path ([System.IO.Path]::GetTempPath()) "StreamXRef/$(Get-Random)/datacache.json"

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

    It "Exports mapped clip results" {
        $KnownGood = (Get-Content -Path "$ProjectRoot/Tests/TestDataCompressedMapping.json").Trim()

        # Mock just the behavior of adding data to mapping
        InModuleScope StreamXRef {
            $script:TwitchData.ClipInfoCache["madeupnameforaclip"].Mapping["one"] = "https://www.twitch.tv/videos/123456789?t=1h35m32s"
        }

        Export-XRefData -Path "$TempPath/CheckData.json" -Compress -Force
        $CheckData = (Get-Content -Path "$TempPath/CheckData.json").Trim()

        $CheckData | Should -Be $KnownGood
    }
}
