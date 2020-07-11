#Requires -RunAsAdministrator
#Requires -Version 5
#Requires -Module @{ ModuleName = "Hyper-V"; ModuleVersion = "2.0.0.0"; Guid = "af4bddd0-8583-4ff2-84b2-a33f5c8de8a7" }

using module Hyper-V

$script:PackedApiExe = "$PSScriptRoot\api.exe"

# Hack to make this module auto-update api.exe from the directory structure of the repository
if (!(Test-Path $script:PackedApiExe -PathType Leaf) -and (Test-Path "$PSScriptRoot\..\go\api.exe" -PathType Leaf)) {
	copy "$PSScriptRoot\..\go\api.exe" $PSScriptRoot
}

. "$PSScriptRoot\GoFilePath-ClassDefs.ps1"

. "$PSScriptRoot\New-GoPaths.ps1"
. "$PSScriptRoot\Remove-GoPaths.ps1"

. "$PSScriptRoot\Get-GoFilePath.ps1"
. "$PSScriptRoot\Set-GoFilePath.ps1"

New-Alias -Name gof -Value Get-GoFilePath

Export-ModuleMember -Function New-GoPaths
Export-ModuleMember -Function Remove-GoPaths
Export-ModuleMember -Function Get-GoFilePath -Alias *
Export-ModuleMember -Function Set-GoFilePath
