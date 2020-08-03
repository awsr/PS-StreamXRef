#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.2' }

BeforeAll {
    Get-Module StreamXRef | Remove-Module
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module "$ProjectRoot/Module/StreamXRef.psd1" -Force
    Import-Module Microsoft.PowerShell.Utility -Force

    function MakeMockHTTPError {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)]
            [ValidateSet(404, 503)]
            [int]$Code
        )

        $ErrorData = @{}
        $ErrorData.404 = @{
            Code    = [System.Net.HttpStatusCode]::NotFound
            String  = "Response status code does not indicate success: 404 (Not Found)."
            Details = '{"error":"Not Found","status":404,"message":""}'
        }
        $ErrorData.503 = @{
            Code    = [System.Net.HttpStatusCode]::ServiceUnavailable
            String  = "Response status code does not indicate success: 503 (Service Unavailable)."
            Details = "I don't remember what the error details should look like, but this doesn't really matter."
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            # Legacy exception
            $Status = [System.Net.WebExceptionStatus]::ProtocolError
            $Response = [System.Net.HttpWebResponse]::new()
            # Workaround for being unable to set response code normally
            $Response | Add-Member -MemberType NoteProperty -Name StatusCode -Value ($ErrorData[$Code].Code) -Force
            $Exception = [System.Net.WebException]::new($ErrorData[$Code].String, $null, $Status, $Response)
        }
        else {
            # Current exception
            $Response = [System.Net.Http.HttpResponseMessage]::new($ErrorData[$Code].Code)
            $Exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new($ErrorData[$Code].String, $Response)
        }

        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
            $Exception,
            "WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeRestMethodCommand",
            ([System.Management.Automation.ErrorCategory]::InvalidOperation),
            $null
        )
        $ErrorRecord.ErrorDetails = $ErrorData[$Code].Details
        return $ErrorRecord
    }
}

Describe "HTTP response errors" -Tag HTTPResponse {
    BeforeAll {
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            # See https://github.com/PowerShell/PowerShell/pull/10840
            $global:TestErrorOffset = 1
        }
        else {
            $global:TestErrorOffset = 0
        }

        Import-XRefData -ApiKey notreal -Quiet -Force
    }
    AfterAll {
        Remove-Variable -Name TestErrorOffset -Scope Global -ErrorAction Ignore
    }

    Context "404 Not Found" {
        BeforeAll {
            Mock Invoke-RestMethod -ModuleName StreamXRef -ParameterFilter { $Uri -notlike "*ValidClipName" } -MockWith {
                $PSCmdlet.ThrowTerminatingError($(MakeMockHTTPError -Code 404))
            }
        }

        It "Clip name not found" {
            $Result = Find-TwitchXRef -Source ClipNameThatResultsIn404Error -XRef TestVal -ErrorVariable TestErrs -ErrorAction SilentlyContinue

            $TestErrs[$TestErrorOffset].InnerException.Response.StatusCode | Should -Be 404
            $Result | Should -BeNullOrEmpty
        }

        It "Clip URL not found" {
            $Result = Find-TwitchXRef -Source "https://clip.twitch.tv/AnotherBadClipName" -XRef "TestVal" -ErrorVariable TestErrs -ErrorAction SilentlyContinue

            $TestErrs[$TestErrorOffset].InnerException.Response.StatusCode | Should -Be 404
            $Result | Should -BeNullOrEmpty
        }

        It "Video URL not found" {
            $Result = Find-TwitchXRef -Source "https://www.twitch.tv/videos/123456789?t=1h23m45s" -XRef "TestVal" -ErrorVariable TestErrs -ErrorAction SilentlyContinue

            $TestErrs[$TestErrorOffset].InnerException.Response.StatusCode | Should -Be 404
            $Result | Should -BeNullOrEmpty
        }

        It "Continues with next entry in the pipeline" {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like "*ValidClipName" } -MockWith {
                return [pscustomobject]@{
                    broadcaster = [pscustomobject]@{
                        id        = 22446688
                        name      = "someone"
                    }
                    vod         = [pscustomobject]@{
                        id        = 123456789
                        offset    = 2468
                        url       = "https://notimportant.com/because/not/being/checked/in/this/test"
                    }
                    created_at  = [datetime]::UtcNow
                }
            }
            $TestArray = @(
                [pscustomobject]@{ Source = "BadClipName"; XRef = "TestVal" },
                [pscustomobject]@{ Source = "ValidClipName"; XRef = "TestVal" }
            )

            $Result = $TestArray | Find-TwitchXRef -ErrorVariable TestErrs -ErrorAction SilentlyContinue

            $TestErrs[$global:TestErrorOffset].InnerException.Response.StatusCode | Should -Be 404 -Because "only the call with 'ValidClipName' is mocked with values"
            Should -Invoke "Invoke-RestMethod" -Exactly 3  # 1 404 response, 1 response with data, then 1 404 response
            $Result | Should -BeNullOrEmpty
        }

        It "Added valid data to cache before encountering 404" {
            InModuleScope StreamXRef {
                $TwitchData.ClipInfoCache.Keys | Should -Contain "validclipname"
                $TwitchData.ClipInfoCache["validclipname"].offset | Should -Be 2468
            }
        }
    }

    Context "503 Service Unavailable" {
        It "503 during clip lookup" {
            Mock Invoke-RestMethod -ModuleName StreamXRef -MockWith {
                $PSCmdlet.ThrowTerminatingError($(MakeMockHTTPError -Code 503))
            }

            { Find-TwitchXRef -Source "https://clip.twitch.tv/WhatCouldGoWrong" -XRef "TestVal" } | Should -Throw
        }
    }
}

Describe "Data caching" {
    BeforeAll {
        Clear-XRefData -RemoveAll
        Import-XRefData $ProjectRoot/Tests/TestData.json -Quiet -Force

        # Catchall mock to ensure Invoke-RestMethod doesn't leak
        Mock Invoke-RestMethod -ModuleName StreamXRef -MockWith {
            $PSCmdlet.ThrowTerminatingError( (MakeMockHTTPError -Code 404) )
        }

        Mock Invoke-RestMethod -ModuleName StreamXRef -ParameterFilter { $Uri -like "*11111111/videos" } -MockWith {
            $MultiObject = [pscustomobject]@{
                _total = 1234
                videos = @()
            }
            $MultiObject.videos += [pscustomobject]@{
                broadcast_type = "archive"
                recorded_at    = [datetime]::new(2020, 5, 31, 3, 14, 15, [System.DateTimeKind]::Utc)
                length         = 3000
                url            = "https://www.twitch.tv/videos/111444111"
            }
            $MultiObject.videos += [pscustomobject]@{
                broadcast_type = "archive"
                recorded_at    = [datetime]::new(2020, 5, 31, 1, 22, 44, [System.DateTimeKind]::Utc)
                length         = 5000
                url            = "https://www.twitch.tv/videos/111222333"
            }
            return $MultiObject
        }
    }

    It "Uses cached clip and UserID" {
        # Mock won't be invoked if function doesn't read the cached data
        $Result = Find-TwitchXRef madeupnameforaclip one
        Should -Invoke "Invoke-RestMethod" -ModuleName StreamXRef -Exactly 1
        $Result | Should -Be "https://www.twitch.tv/videos/111222333?t=0h40m4s"
    }

    It "Created Clip to User mapping entry" {
        InModuleScope StreamXRef {
            $TwitchData.ClipInfoCache["madeupnameforaclip"].Mapping.Keys | Should -Contain "one"
        }
    }

    It "Uses cached Clip to User mapping data for quick result" {
        [void] (Find-TwitchXRef madeupnameforaclip one)
        Should -Invoke "Invoke-RestMethod" -ModuleName StreamXRef -Exactly 0
    }

    It "Matches cached data with different capitalization" {
        $Result = Find-TwitchXRef MADEUPNAMEFORACLIP ONE
        $Result | Should -Be "https://www.twitch.tv/videos/111222333?t=0h40m4s"
    }
}

Describe "Custom ErrorIds" {
    BeforeAll {
        Clear-XRefData -RemoveAll
        Import-XRefData $ProjectRoot/Tests/TestData.json -Quiet -Force
    }

    It "MissingTimestamp" {
        { Find-TwitchXRef "https://twitch.tv/videos/123456789" "TestVal" -ErrorAction Stop } | Should -Throw -ErrorId "MissingTimestamp,Find-TwitchXRef"
    }

    It "VideoNotFound" {
        Mock Invoke-RestMethod -ModuleName StreamXRef -MockWith {
            return [pscustomobject]@{
                slug = "ClipDoesNotMatterHere"
                url  = "https://clips.twitch.tv/ClipDoesNotMatterHere"
                vod  = $null
            }
        }

        { Find-TwitchXRef ClipThatIsNotCached TestVal -ErrorAction Stop } | Should -Throw -ErrorId "VideoNotFound,Find-TwitchXRef"
    }

    It "InvalidVideoType" {
        Mock Invoke-RestMethod -ModuleName StreamXRef -MockWith {
            return [pscustomobject]@{
                title          = "Mocked video response"
                broadcast_type = "highlight"
            }
        }

        { Find-TwitchXRef "https://twitch.tv/videos/444444444?t=1h23m45s" "TestVal" -ErrorAction Stop } | Should -Throw -ErrorId "InvalidVideoType,Find-TwitchXRef"
        { Find-TwitchXRef "madeupnameforaclip" "https://twitch.tv/videos/444444444" -ErrorAction Stop } | Should -Throw -ErrorId "InvalidVideoType,Find-TwitchXRef"
    }

    It "UserNotFound" {
        Mock Invoke-RestMethod -ModuleName StreamXRef -ParameterFilter { $Uri -like "*/users" } -MockWith {
            return [pscustomobject]@{
                _total = 0
                users  = @()
            }
        }

        { Find-TwitchXRef madeupnameforaclip NotAUsername -ErrorAction Stop } | Should -Throw -ErrorId "UserNotFound,Find-TwitchXRef"
    }

    It "EventNotInRange" {
        Mock Invoke-RestMethod -ModuleName StreamXRef -ParameterFilter { $Uri -like "*/videos/*" } -MockWith {
            return [pscustomobject]@{
                title          = "Mocked video response"
                broadcast_type = "archive"
                recorded_at    = [datetime]::new(2099, 12, 31, 23, 59, 59, [System.DateTimeKind]::Utc)
                length         = 2000
            }
        }

        { Find-TwitchXRef "madeupnameforaclip" "https://twitch.tv/videos/444444444" -ErrorAction Stop } | Should -Throw -ErrorId "EventNotInRange,Find-TwitchXRef"
    }

    It "EventNotFound" {
        Mock Invoke-RestMethod -ModuleName StreamXRef -MockWith {
            $MultiObject = [pscustomobject]@{
                _total = 1234
                videos = @()
            }
            $MultiObject.videos += [pscustomobject]@{
                title          = "Mocked video response 1"
                broadcast_type = "archive"
                recorded_at    = [datetime]::new(2000, 1, 2, 0, 0, 0, [System.DateTimeKind]::Utc)
                length         = 2000
            }
            $MultiObject.videos += [pscustomobject]@{
                title          = "Mocked video response 2"
                broadcast_type = "archive"
                recorded_at    = [datetime]::new(2000, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)
                length         = 2000
            }
            return $MultiObject
        }

        { Find-TwitchXRef madeupnameforaclip one -ErrorAction Stop } | Should -Throw -ErrorId "EventNotFound,Find-TwitchXRef"
    }
}

Describe "Other exceptions" {
    BeforeAll {
        Clear-XRefData -RemoveAll
        Import-XRefData -ApiKey notreal -Quiet -Force
    }

    It "Throws terminating error when API response doesn't match expected format" {
        Mock Invoke-RestMethod -ModuleName StreamXRef -MockWith {
            return [pscustomobject]@{
                "wait"  = "this"
                "seems" = "wrong"
                "where" = "is"
                "the"   = "data?"
            }
        }

        { Find-TwitchXRef -Source TestClipName -XRef TestVal } | Should -Throw
    }
}
