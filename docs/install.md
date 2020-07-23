# How to Install

The testing infrastructure has some dependencies, here's what they are and how to get them.

## Prerequisites
* Windows
* Hyper-V installed for tests that hit the file system
* PowerShell 7
* (Optional) go SDK to build `api.exe`
* (Optional) .NET SDK (LTS 3.1) to build `epi.exe`

## Installation

#### Hyper-V

* To install Hyper-V on Windows 10:

  ```PowerShell
  PS> Enable-WindowsOptionalFeature -Online Microsoft-Hyper-V-All
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

* This is not required if `epi.exe` was published *Self-contained* or as *single file*.
* To build `epi.exe`, download the SDK.
* To run `epi.exe` if it was published portable, the .NET Core Runtime is sufficient.

The page also lists a script that can be used to install .NET on build servers unattended.

#### PowerShell 7

Simply download and run the appropriate .msi from [PowerShell Releases](https://github.com/PowerShell/PowerShell/releases).

* [PowerShell-7.0.3-win-x64.msi](https://github.com/PowerShell/PowerShell/releases/download/v7.0.3/PowerShell-7.0.3-win-x64.msi) is appropriate at the time of writing.
* If you have the .NET SDK installed, run this command instead and save on duplicating installation of .NET:

  ```
  dotnet tool install --global powershell
  ```

For more information see [Installing PowerShell on Windows - PowerShell | Microsoft Docs](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7#administrative-install-from-the-command-line)

