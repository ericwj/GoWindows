# Go Windows Testing

This repository contains infrastructure to test parts of [go](https://github.com/golang/go) on Windows.

## Docs

* [Overview](docs/overview.md)
* [How to install](docs/install.md)
* [Authoring Tests](docs/authoring.md)
* [Deploying](docs/publish.md)

## How To Use

The workflow while making changes to `epi.exe` may look like this,
assuming the working directory is the root of this repository:

> This **does not** work on the PowerShell that comes pre-installed on Windows.
> Install [PowerShell 7](https://aka.ms/powershell).

```PowerShell
dotnet build .\src\cs\epi.csproj # also builds api.exe
# add api.exe and epi.exe to the path
$env:Path += ";" + "$PWD\src\cs\bin\Debug\netcoreapp3.1"

# Get setup (optional for many tests)
Import-Module .\src\ps\GoSetup.psm1
Mount-Go -EnableCaseSensitiveDirectories -EnableLongPaths

# Inner loop
Remove-Module GoTest; Import-Module .\src\ps\GoTest.psm1
Build-GoClassTests -PathMath | where Api -Match "Join" | ConvertTo-GoCsv | Out-File .\pathmath.csv
Test-Go .\pathmath.csv -GenerateExpected
.\pathmath.results.html # first time only, should open a browser
# make code changes
dotnet build .\src\cs\epi.csproj # also builds api.exe

# Use arrow keys from here to repeat the above commands

Dismount-Go -Force # when done, force shouldn't normally be needed
```

This workflow changes as follows when developing `api.go`:
```PowerShell
# -GenerateExpected is recommended but optional if the tests are not changing
Test-Go .\pathmath.csv
```

The working directory should be the directory where `Mount-Go` will be running.
The test definition files (`.csv`) and expected test result files (`.json`) can be anywhere.
Only the `.csv` file is specified on the command line, the JSON file is expected to be in
the same directory and have the same name.

## Quickly Iterating

Some parts of `GoTest` have so far been frequently modified to suit the needs of the testing required.

Certainly while developing either go or C# code to test it,
it is recommended to keep an editor open to modify Build-GoTests
and similar CmdLets to suit the immediate needs,
then remove and re-install the module before running its modified CmdLets like so:

```PowerShell
Remove-Module GoTest; Import-Module .\GoTest.psm1
```

## Getting Help

The PowerShell module are sufficiently documented through the PowerShell help system.

The following commands list the available commands in a given module
and help for a specific command:

```PowerShell
Install-Module .\GoSetup.psm1
Get-Command -Module GoSetup
Get-Help Mount-Go -Detailed
```

Next to `-Detailed` there is also `-Full` with yet more detail -
to simply see which arguments are supported, either
* type `-` and then tab through the suggestions PowerShell produces,
* or run `Get-Help` with just the name of the CmdLet.

The following general remarks are useful:
* To see what is going on, use the `-Verbose` switch.
* To get swamped, use the `-Debug` switch.
* `Clear-Go` supports the `-WhatIf` switch (all CmdLets do, but
  here it is useful) which shows which files it would delete,
  without actually deleting any.

## Running on a build server

On the build server the process will look mostly like so,
assuming the appropriate CSV files are in the current working directory,
as well as the expected JSON files or that `epi.exe` is on the path:

```PowerShell
$env:Path += ";" + "<path to epi.exe>"
$env:Path += ";" + "<path to api.exe>"

# Import modules
Import-Module .\src\ps\GoSetup.psm1
Import-Module .\src\ps\GoTest.psm1
Mount-Go
Test-Go .\file1.csv
Test-Go .\file2.csv
$failures = 0
foreach ($json in (dir *.failures.json)) {
	# oneliner
	$failures += (Get-Content $json | ConvertFrom-Json | measure).Count
	# or to be verbose about it
	foreach ($failure in (Get-Content $json | ConvertFrom-Json)) {
		Write-Error "Test Failure: $failure"
		$failures++
	}
}
exit $failures # use the failure count as exit code
```
> test.ps1
```cmd
pwsh -File ".\test.ps1" -ExecutionPolicy Unrestricted -NonInteractive -NoProfile -WorkingDirectory "path"
if errorlevel 1 goto :FailTheBuild
(...)
```
> test.cmd (Elevated)

`Dismount-Go` is not required if the build machine will be torn down after the test run.

If the terminal session closes in which `Mount-Go` has ran, the values of environment variables
are lost and `Dismount-Go` will need to be run in the appropriate directory with the `-Force` argument
to get rid of the `Peculiar` directory and *any and all* .vhdx files, mounted or not, in that directory.

## Common Errors

The most common error is complaints about end of file reading expected or actual test results
from `api.exe` or `epi.exe`.
This is an indication that the .csv file does not match the expected test results,
or that either `api.exe` or `epi.exe` exited prematurely.

Both executables absolutely require valid JSON and valid values for the `Api` parameter.
Neither will prematurely exit over invalid arguments provided to a valid API.
