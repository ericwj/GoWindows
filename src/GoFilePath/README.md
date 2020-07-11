# GoFilePath

This directory contains a PowerShell module with several functions that help test go file API's.

* `New-GoPaths` creates a virtual disk, mounts it, creates directories on it, creates
  network shares to these folders and finally maps these shares through `\\COMPUTERNAME\share`
  to a local drive letter. The result it returns contains names and actual objects that were
  created. The only argument is a unique name which is used as (part of the) name of
  the virtual disk, directories and other objects; if not specified, it defaults to `GoFilePath`.
* `Remove-GoPaths` does the reverse of `New-GoPaths` as it deletes drive mappings and shares
  in the provided object (the result of `New-GoPaths`) and deletes the virtual disk that that
  function created.
* `Set-GoFilePath` is a little helper function to set both the operating system working
  directory and the PowerShell `$PWD` in a single command and to return both.
  PowerShells `$PWD` is not the operating system working directory normally; usually,
  PowerShell might run with the operating system working directory set forever to
  `$env:windir\System32`. If the path provided is `$null`, the command performs no action
  but returns the current value of both paths.
* `Get-GoFilePath` is documented below.

## How to use

The easiest is to clone the whole repository and then use
```PowerShell
PS> Import-Module .\path\to\GoFilePath\
```

All PowerShell functions provide information about the parameters they support by typing
for example
```PowerShell
Get-Help Get-GoFilePath
```

To remove the module, or to re-install the module, first remove it
```PowerShell
PS> Remove-Module .\path\to\GoFilePath\
```

All commands make reasonable use of `Write-Verbose` and all commands pose as CmdLets,
such that the `-Verbose` switch is always implicitly available. This will produce
extra output about the actions that are being performed.

## `Get-GoFilePath`

`Get-GoFilePath` is a PowerShell function to invoke Go stdlib `path/filepath` functions.

Uses the executable produced from `api.go` in this repository.

The script expects `api.go` to be compiled to `api.exe` and the executable to exist at any one of.
* The path provided in the optional `-UseGoApiExecutable` function parameter.
* In the module directory.
* In the location pointed to by `$env:GOAPI`.
* On the `$env:PATH`.
* In the current directory or a directory below it.
In that order.

### `Get-GoFilePath.ps1`

Be sure to use the `Tab` key a lot. This will cause PowerShell to
autocomplete the function name as well as arguments and provides
immediate usability without having to check go API declarations:

```PowerShell
PS> get-gof<Tab> -<TabTab> -<TabTab> C:\<TabTab>
```

### Arguments

Arguments are all positional, such that except for the first one, the `-` and argument name can be omitted.
1. The switch to select a go API is the first argument and is required.
1. Usually a `Path` argument follows second, or e.g. `Root` for `Walk` which is declared with first argument `root string` in go.
1. Depending on the go API, a second argument to the API may be required, which is then the third argument in PowerShell.

For more help:
```PowerShell
PS> Get-Help Get-GoFilePath
```

The alias is `gof`:

```PowerShell
PS> Get-Help gof
```

### Examples

```PowerShell
PS> Get-GoFilePath -Abs .
```

```PowerShell
PS> gof -IsAbs .
```

```PowerShell
PS> Get-GoFilePath -Walk -Root $env:USERPROFILE -UseGoApiExecutable C:\api.exe
```

Or on Linux (probably mostly similar to)
```PowerShell
PS> Get-GoFilePath -Walk -Root ~ -UseGoApiExecutable ~/go/api
```
