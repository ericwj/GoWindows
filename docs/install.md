# How to Install


## Prerequisites

The testing infrastructure has some dependencies, here's what they are and how to get them.
* Windows
* Hyper-V installed for tests that hit the file system
* PowerShell 7
* go SDK to build `api.exe`
* .NET SDK to build `epi.exe` or .NET Core Runtime to run it if it was published as portable

#### Hyper-V

* To install Hyper-V on Windows 10:

  ```PowerShell
  PS> Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
  ```

  This installs the Hyper-V hypervisor. If another hypervisor is already installed,
  you may try to avoid installing it as follows. This has not been tested;
  please report back whether this actually works:

  ```PowerShell
  PS> Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell, Microsoft-Hyper-V-Services
  ```
  -or-
  ```PowerShell
  PS> Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell, Microsoft-Hyper-V-Services, Microsoft-Hyper-V
  ```
  If that works with another hypervisor installed, run the following to see if that produces a `.vhdx` file or an error.
  ```PowerShell
  New-Vhd Test.vhdx -Size 3MB -Fixed
  Mount-Vhd Test.vhdx
  Dismount-Vhd Test.vhdx
  del Test.vdhx
  ```

* To install Hyper-V on Windows Server, the server must be hardware
with SLAT and VT-x or similar enabled or have access to nested virtualization:

  ```PowerShell
  PS> Set-VMProcessor -VMName TestGoVM -ExposeVirtualizationExtensions:$true
  ```

  Then install Hyper-V:
  ```PowerShell
  PS> Install-WindowsFeature Hyper-V -Restart
  PS> Install-WindowsFeature Hyper-V-PowerShell
  ```

#### .NET

Download from [Download .NET Core 3.1 (Linux, macOS, and Windows)](https://dotnet.microsoft.com/download/dotnet-core/3.1) for the appropriate architecture.

* This is not required if `epi.exe` was published *Self-contained* or as *single file*,
  but remains recommended since the .NET runtime is shared with PowerShell 7.
* To build `epi.exe`, download the SDK.
* To run `epi.exe` if it was published portable, the *.NET Core Runtime* is sufficient.

The page also lists a script that can be used to install .NET on build servers unattended.

#### PowerShell 7

* If you have the .NET SDK installed, run this command instead and save on duplicating installation of .NET:

  ```PowerShell
  dotnet tool install --global powershell
  ```
* Or simply download and run the appropriate .msi from [PowerShell Releases](https://github.com/PowerShell/PowerShell/releases).

* [PowerShell-7.0.3-win-x64.msi](https://github.com/PowerShell/PowerShell/releases/download/v7.0.3/PowerShell-7.0.3-win-x64.msi) is appropriate at the time of writing.

For more information see [Installing PowerShell on Windows - PowerShell | Microsoft Docs](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7#administrative-install-from-the-command-line)

## Installing From Sources

After cloning this repository, the following steps may be used to build and run each of the components.

#### PowerShell modules

The PowerShell modules are simply script files renamed to `.psm1` and can be imported as-is into PowerShell 7
from their file location:

```PowerShell
Import-Module .\src\ps\GoSetup.psm1
Import-Module .\src\ps\GoTest.psm1
```

The `Remove-Module` command can be used to remove them from the current session,
after which the above commands can again be executed to import an updated version.

#### `api.exe`

To build just `api.exe`, run

```
go build .\src\go\api.go
```
-or-
```
dotnet build .\src\go
```

#### `epi.exe`

To build just `epi.exe` in a standard portable debug configuration, run

```PowerShell
dotnet build .\src\cs
```

This also builds `api.exe` and includes it in the project output.

To publish `epi.exe`, one of three deployment methods can be used like so:

```PowerShell
dotnet publish .\src\cs /p:PublishProfile=Portable
dotnet publish .\src\cs /p:PublishProfile=SelfContained
dotnet publish .\src\cs /p:PublishProfile=SingleFile
```
Each of these create a folder in `.\publish` with the result of the publish build.
`api.exe` is each time included, but with the *SingleFile* publish method,
the executable is only on disk *after* `epi.exe` has started and its location
is a temporary directory in `$env:Temp\.net`.
Hence in this case it is easier to ship it separately and put it on the path separately.

|Publish Profile Name|Size|Description|
|:--|--:|:--|
|Portable|1.5MB|Can be run with .NET Core Runtime 3.1 latest installed on the machine or present in a local directory as binaries only.
|SelfContained|60MB|Can be `xcopy` deployed and ran in-place.
|SingleFile|61MB|Copy be ` xcopy` deployed and will basically unzip and run like the *Self-contained* profile.

The publish profiles are configured not to use IL Linking or producing ready-to-run-compiled output.
To try these features and see if they make a difference in deployment size, change the
`PublishTrimmed` and `PublishReadyToRun` properties in `.\src\cs\Properties\PublishProfiles\*.pubxml`.
