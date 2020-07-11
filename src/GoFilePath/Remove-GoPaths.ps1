#Requires -RunAsAdministrator
#Requires -Version 5
#Requires -Module @{ ModuleName = "Hyper-V"; ModuleVersion = "2.0.0.0"; Guid = "af4bddd0-8583-4ff2-84b2-a33f5c8de8a7" }

<#
	.Synopsis
	Tears down a test environment to run go API against.
#>
function Remove-GoPaths {
	[CmdLetBinding()]
	Param(
		[ValidateNotNull()]
		[GoPaths]$paths
	)
	Process {
		if ($null -eq $paths) {
			Write-Error "Cannot continue. '`$paths' is '`$null'."
			return
		}
		foreach ($mapping in $paths.SmbMappings) {
			if ($null -eq $mapping) { continue }
			$existing = Get-SmbMapping -LocalPath $mapping.LocalPath -ErrorAction SilentlyContinue
			if ($null -eq $existing) { continue }
			Write-Verbose "Deleting SMB mapping '$($existing.LocalPath)' => '$($existing.RemotePath)'"
			$existing | Remove-SmbMapping -Confirm:$false
		}
		foreach ($share in $paths.ShareNames) {
			if ($null -eq $share) { continue }
			$existing = Get-SmbShare -Name $share.Name -ErrorAction SilentlyContinue
			if ($null -eq $existing) { continue }
			Write-Verbose "Deleting SMB share '$($existing.Name)' => '$($existing.Path)'"
			$existing | Remove-SmbShare -Confirm:$false
		}
		foreach ($junction in $paths.Junctions) {
			if ([string]::IsNullOrEmpty($junction)) { continue }
			if ([System.IO.Directory]::Exists($juction)) {
				Write-Verbose "Deleting junction '$junction'"
				rmdir $junction
			}
		}
		$fn = $paths.VhdFile
		if ($null -eq $fi -or $null -eq (dir $fn)) {
			Write-Warning "The virtual disk file '$($fn)' does not exist. The virtual disk is not dismounted or deleted."
			return
		}
		$vhd = Get-Vhd $fn
		if ($null -eq $vhd) {
			Write-Warning "The file '$fn' does not appear to be a virtual disk. The disk is not dismounted or deleted."
		}
		Write-Verbose "Dismounting '$($vhd.Path)'."
		$vhd | Dismount-Vhd -ErrorAction Stop
		Write-Verbose "Deleting '$($vhd.Path)'."
		del $fn -ErrorAction Stop
	}
}
