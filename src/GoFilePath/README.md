### PowerShell `api` invokes Go stdlib functions

Uses the executable produced from `api.go` in this repository.

Use like so `. .\GoFilePath.ps1`, followed by lots of `Tab` presses:

```PowerShell
get-gof<Tab> -<TabTab> -<TabTab> C:\<TabTab>
```

The script expects `api.go` to be compiled to `.\api.exe` in the current directory,
but will search `$env:Path` for `api.exe` as well as `$PWD` and directories below it.

For more help:
```PowerShell
Get-Help Get-GoFilePath
```

The alias is `gof`:

```PowerShell
Get-Help gof
```

### Examples (PowerShell syntax)

```PowerShell
PS> Get-GoFilePath -Abs .
```

```PowerShell
PS> gof -IsAbs .
```

```PowerShell
PS> Get-GoFilePath -Walk . -UseGoApiExecutable C:\api.exe
```

Or on Linux (probably mostly similar to)
```PowerShell
PS> Get-GoFilePath -Walk ~ -UseGoApiExecutable ~/go/api
```
