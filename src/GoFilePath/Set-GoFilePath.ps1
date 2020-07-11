<#
	.Synopsis
	A convenience function that changes the PowerShell $PWD
	as well as the operating system working directory.

	The operating system path is changed first.
	PowerShell may fail to follow the operating system working directory; this will be visible as an error in the console
	and in the result that is returned regardless.

	The operating system working directory can be made to follow
	the PowerShell `$PWD by requesting the current directory be set (.).

	Both are returned in the result, even for a $null argument,
	in which case no attempt is made to make any changes.
#>
function Set-GoFilePath {
	[CmdLetBinding()]
	Param(
		[AllowNull()][AllowEmptyString()][string]$Path
	)
	Process {
		try {
			if ("." -eq $Path) {
				[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
			} elseif ($null -ne $Path) {
				[System.IO.Directory]::SetCurrentDirectory($Path)
				cd $Path
			}
			return @{
				OS = [System.IO.Directory]::GetCurrentDirectory()
				PS = $PWD
			}
		} catch {
			Write-Error ($Error | select -Last 1)
			return @{
				OS = [System.IO.Directory]::GetCurrentDirectory()
				PS = $PWD
			}
		}
	}
}
