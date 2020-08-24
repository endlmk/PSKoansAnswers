using module PSKoans
[Koan(Position = 202)]
param()
<#
    PSProviders

    Providers are PowerShell's general-purpose solution for accessing resources. The default set of
    providers that come with PowerShell on all platforms are listed below:

    Name                 Capabilities                            Drives
    ----                 ------------                            ------
    Alias                ShouldProcess                           {Alias}
    Environment          ShouldProcess                           {Env}
    FileSystem           Filter, ShouldProcess, Credentials      {/}
    Function             ShouldProcess                           {Function}
    Variable             ShouldProcess                           {Variable}

    Several are for accessing internal PowerShell resources (aliases, functions, variables), but the
    rest typically interact with the surrounding environment like the filesystem or OS environment.

    On Windows, PowerShell also comes with a Registry provider, for interacting with the Windows
    registry.

    All providers that have a defined function with the Get-Content cmdlet can also be accessed
    similarly to variable scopes, e.g., { $env:PATH } instead of { Get-Content 'env:PATH' }
#>
Describe 'Alias Provider' {
    <#
        Aliases are PowerShell command shortcuts. By querying the Alias: provider, you can get a
        list of all command shortcuts in the current session. The available aliases may increase
        when a new module is imported.
    #>
    Context 'Direct Access' {
        BeforeAll {
            $Aliases = Get-ChildItem -Path 'Alias:'
        }

        It 'can be queried with generic provider cmdlets' {
            '__' | Should -Be $Aliases.Name[0]
            'Get-Blank' | Should -Be $Aliases.Definition[0]
        }

        It 'maps aliases to the full command' {
            $Alias = 'sl'
            $AliasObject = Get-Item -Path "Alias:\$Alias" -ErrorAction SilentlyContinue

            $AliasObject | Get-Content | Should -Be 'Set-Location'
        }

        It 'can create aliases too!' {
            127 | Should -Be $Aliases.Count

            New-Item -Path 'Alias:\grok' -Value 'Get-Item' -ErrorAction SilentlyContinue

            $File = grok './PSKoans/Cmdlets 1/AboutCompareObject.Koans.ps1' -ErrorAction SilentlyContinue
            $File | Should -BeOfType [System.IO.FileInfo]

            $Aliases2 = Get-ChildItem -Path 'Alias:'
            128 | Should -Be $Aliases2.Count

            Remove-Item -Path 'Alias:\grok'
        }
    }

    Context 'Access Via Cmdlet' {

        It 'can be accessed with Get-Alias' {
            # These commands are effectively equivalent
            $AliasObjects = Get-ChildItem -Path 'Alias:'
            $AliasObjects2 = Get-Alias

            127 | Should -Be $AliasObjects2.Count
            $AliasObjects.Count | Should -Be $AliasObjects2.Count
        }

        It 'can seek out aliases for a command' {
            $CmdletName = 'Get-ChildItem'
            $AliasData = Get-Alias -Definition $CmdletName

            $AliasData.Name | Should -Be @('dir', 'gci')
        }

        It 'can be used to find the associated command' {
            $AliasData = Get-Alias -Name 'ft'

            'Format-Table' | Should -Be $AliasData.Definition
        }

        It 'can create aliases too!' {
            # New-Alias and Set-Alias can both create aliases; Set-Alias will overwrite existing ones, however.
            Set-Alias -Name 'grok' -Value 'Get-Item'
            $File = grok $home

            $File | Should -BeOfType [System.IO.DirectoryInfo]
        }
    }

    Context 'Variable Access' {

        It 'can be accessed like a variable' {
            'Get-ChildItem' | Should -Be $Alias:gci
        }

        It 'is the same as using Get-Content on the path' {
            Get-Content -Path 'Alias:\gcm' | Should -Be $Alias:gcm

            $AliasTarget = Get-Content -Path 'Alias:\echo'
            'Write-Output' | Should -Be $AliasTarget
        }
    }
}

Describe 'Environment Provider' {
    <#
        The Env: drive contains system environment data. Its contents can vary wildly from OS to OS,
        especially between Windows, Mac, and Linux, for example.

        The only shared Env: items across all OS's currently are Path and PSModulePath.
    #>
    $EnvironmentData = Get-ChildItem -Path 'Env:'

    It 'allows access to system environment data' {
        $SelectedItem = $EnvironmentData.Where{ $_.Value -is [string] }[7]
        $Content = $SelectedItem | Get-Content

        'en_US.UTF-8' | Should -Be $Content
        'LANG' | Should -Be $SelectedItem.Name
    }

    It 'can be accessed via variables' {
        '/opt/microsoft/powershell/7:/root/.vscode-server/bin/3dd905126b34dcd4de81fa624eb3a8cbe7485f13/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' | Should -Be $env:PATH
    }
}

Describe 'FileSystem Provider' {
    BeforeAll {
        $Path = 'TestDrive:' | Join-Path -ChildPath 'File001.tmp'

        $FileContent = @'
PSKOANS!
The Env: drive contains system environment data. Its contents can vary wildly from OS to OS,
especially between Windows, Mac, and Linux, for example.
'@
        Set-Content -Path $Path -Value $FileContent
    }
    It 'allows access to various files and their properties' {
        $File = Get-Item -Path $Path

        'File001.tmp' | Should -Be $File.Name
        'Normal' | Should -Be $File.Attributes
        '159' | Should -Be $File.Length
    }

    It 'allows you to extract the contents of files' {
        $FirstLine = Get-Content -Path $Path | Select-Object -First 1
        'PSKOANS!' | Should -Be $FirstLine
    }

    It 'allows you to copy, rename, or delete files' {
        $File = Get-Item -Path $Path

        $NewPath = "$Path-002"
        $NewFile = Copy-Item -Path $Path -Destination $NewPath -PassThru

        $NewFile.Length | Should -Be $File.Length
        'File001.tmp-002' | Should -Be $NewFile.Name

        $NewFile = Rename-Item -Path $NewPath -NewName 'TESTNAME.tmp' -PassThru
        'TESTNAME.tmp' | Should -Be $NewFile.Name
        '159' | Should -Be $NewFile.Length

        $FilePath = $NewFile.FullName
        Remove-Item -Path $FilePath
        { Get-Item -Path $FilePath -ErrorAction Stop } | Should -Throw -ExceptionType 'System.Management.Automation.ItemNotFoundException'
    }
}

Describe 'Function Provider' {
    BeforeAll {
        $Functions = Get-ChildItem -Path 'Function:'
    }

    It 'allows access to all currently loaded functions' {
        $ProperlyNamedFunction = $Functions |
            Where-Object {$_.Verb -and $_.Noun} |
            Select-Object -First 1
        # Most proper functions are named in the Verb-Noun convention
        'Add' | Should -Be $ProperlyNamedFunction.Verb
        'AssertionOperator' | Should -Be $ProperlyNamedFunction.Noun
        'Add-AssertionOperator' | Should -Be $ProperlyNamedFunction.Name
    }

    It 'exposes the entire script block of a function' {
        $Functions[3].ScriptBlock | Should -BeOfType ScriptBlock
        652 | Should -Be $Functions[1].ScriptBlock.ToString().Length

        $Functions[4] | Get-Content | Should -BeOfType ScriptBlock
    }

    It 'allows you to rename the functions however you wish' {
        function Test-Function {'Hello!'}

        $TestItem = Get-Item -Path 'Function:\Test-Function'
        Test-Function | Should -Be 'Hello!'

        $TestItem | Rename-Item -NewName 'Get-Greeting'
        'Hello!' | Should -Be (Get-Greeting)
    }

    It 'can also be accessed via variables' {
        function Test-Function {'Bye!'}
        <#
            Because most functions use hyphens, their names are atypical for variables, and the ${}
            syntax must be used to indicate to the PowerShell parser that all contained characters
            are part of the variable name.
        #>
        ${function:Test-Function} | Should -BeOfType ScriptBlock
    }

    It 'can be defined using variable syntax' {
        <#
            Although more code than the usual method of creating functions, it is a quick way to make a
            function out of a script block.
        #>
        $Script = { 1..3 }
        ${function:Get-Numbers} = $Script

        # Invoking script with & is very similar to calling a function name.
        & $Script | Should -Be (Get-Numbers)

        $Values = @(
            1,
            2,
            3
        )
        $Values | Should -Be (Get-Numbers)
    }
}

Describe 'Variable Provider' {
    <#
        The variable provider allows direct access to variables as objects, allowing you to determine
        the name, value, and metadata of variables that are available in the current session and scope.
    #>
    Context 'Generic Cmdlets' {

        It 'allows access to variables in the current scope' {
            Set-Variable -Name 'Test' -Value 22
            $VariableData = Get-Item -Path 'Variable:\Test'

            $VariableData.Name | Should -Be 'Test'
            22 | Should -Be $VariableData.Value
            'None' | Should -Be $VariableData.Options
        }

        It 'allows you to remove variables' {
            $Test1 = 123

            123 | Should -Be $Test1

            Remove-Item -Path 'Variable:\Test1'
            # $null | Should -Be $Test1
            # { Get-Item -Path 'Variable:\Test1' -ErrorAction Stop } | Should -Throw -ExceptionType 'System.Management.Automation.ItemNotFoundException'
        }

        It 'exposes data from default variables' {
            $Variables = Get-ChildItem -Path 'Variable:'

            'High' | Should -Be $Variables.Where{$_.Name -eq 'ConfirmPreference'}.Value
            $null | Should -Be $Variables.Where{$_.Name -eq 'MaximumAliasCount'}.Value
            59 | Should -Be $Variables.Count
        }

        It 'allows you to set variable options' {
            Set-Variable -Name 'Test' -Value 'TEST'

            $Var = Get-Item -Path 'Variable:\Test'
            $Var.Options = [System.Management.Automation.ScopedItemOptions]::ReadOnly

            'TEST' | Should -Be $Var.Value
            { Remove-Item -Path 'Variable:\Test' -ErrorAction Stop } | Should -Throw -ExceptionType System.Management.Automation.SessionStateUnauthorizedAccessException
        }
    }

    Context 'Variable Cmdlets' {

        It 'works similarly to the generic cmdlets' {
            Set-Variable -Name 'test' -Value 7357

            $Info = Get-Variable -Name 'Test'
            'test' | Should -Be $Info.Name
            'None' | Should -Be $Info.Options
            7357 | Should -Be $Info.Value
        }

        It 'can retrieve just the value' {
            Set-Variable -Name 'GetMe' -Value 'GOT!'

            $Get = Get-Variable -Name 'GetMe' -ValueOnly

            'GOT!' | Should -Be $Get
        }
    }
}
