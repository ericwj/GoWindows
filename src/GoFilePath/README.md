## `Get-GoFilePath`

`Get-GoFilePath` is a PowerShell function to invoke Go stdlib `path/filepath` functions.

Uses the executable produced from `api.go` in this repository.

The script expects `api.go` to be compiled to `.\api.exe` in the current directory,
but will search `$env:Path` for `api.exe` as well as `$PWD` and directories below it.

### `Get-GoFilePath.ps1`

The `.ps1` file is a script that defines the `Get-GoFilePath` function. Execute dot-sourced, like so:

```PowerShell
PS> . .\GoFilePath.ps1
```

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
