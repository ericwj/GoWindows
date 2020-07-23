#Requires -RunAsAdministrator
#Requires -Version 5
#Requires -Module @{ ModuleName = "Hyper-V"; ModuleVersion = "2.0.0.0"; Guid = "af4bddd0-8583-4ff2-84b2-a33f5c8de8a7" }

using module Hyper-V

[int]$script:MaxPathSegment = 260 - 5

<#
	.Synopsis
	Performs steps to setup an environment to test go in the current directory.

	.Description
	Several virtual disks will be created and a single directory called Peculiar.

	In the root of these disks and in the directory, a peculiar directory structure will be built.

	Environment variables are set that can then be used by Test-Go.

	.Parameter UniqueName
	A name that will propagate in various places.

	This command requires that there are no network shares with this name on this machine.

	Changing this has not been tested.

	.Parameter EnableCaseSensitiveDirectories
	Allows opting into case sensitive directories. This requires enabling a global opt-in switch in the registry.

	The applicable directories will be created if this switch is not present, but will not be made actually case sensitive.

	.Parameter EnableLongPaths
	Allows opting into testing with the new long path support behavior. This requires enabling a global opt-in switch in the registry.

	Long paths are supported in Windows without this switch, however they must be explicitly handed to Windows APIs with the no-parse prefix (\\?\).

	The applicable directories will be created if this switch is not present, but will not be accessible without no-parse prefix.

	.Parameter SkipVolGuid
	Skips creating this virtual disk. For testing purposes.
	.Parameter SkipDrive
	Skips creating this virtual disk. For testing purposes.
	.Parameter SkipIdentity
	Skips creating this virtual disk. For testing purposes.
	.Parameter SkipJunction
	Skips creating this virtual disk. For testing purposes.
	.Parameter SkipHardLink
	Skips creating this virtual disk. For testing purposes.
#>
function Mount-Go {
	[CmdLetBinding()]
	Param(
		[ValidateNotNullOrEmpty()]
		[ValidateLength(1, 14)]
		[ValidatePattern("\w+")]
		[string]$UniqueName = "GoFilePath",

		[switch]$EnableCaseSensitiveDirectories = [switch]::new($false),
		[switch]$EnableLongPaths = [switch]::new($false),

		[switch]$SkipVolGuid = [switch]::new($false),
		[switch]$SkipDrive = [switch]::new($false),
		[switch]$SkipIdentity = [switch]::new($false),
		[switch]$SkipJunction = [switch]::new($false),
		[switch]$SkipHardLink = [switch]::new($false)
	)
	Begin {
		if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
			Write-Verbose "Skipping setup because the operating system is not Windows."
			return;
		}
		if ($PWD.Provider.Name -ne "FileSystem") {
			throw "Cannot run in the current PowerShell working directory. The `$PWD is from provider '$($PWD.Provider.Name)'. Change the working directory to a normal file system path then try again."
		}
		if (($PWD.Path -match "[\\\/]Peculiar([\\\/]|`$)") -or (Test-Path Peculiar)) {
			throw "There is already a peculiar directory here. Delete and retry."
		}
		if ($null -ne (Get-SmbShare -Name $UniqueName -ErrorAction SilentlyContinue)) {
			throw "A share with name '$UniqueName' already exists. Delete and retry."
		}
		$Suffixes = $env:GoTestSuffixes -split ";"
		foreach ($Suffix in $Suffixes) {
			$vhddisk = Get-Disk  |
				where BusType -Match "File Backed Virtual" |
				where { [System.IO.Path]::GetFileName($_.Location) -eq "$UniqueName$Suffix.vhdx" }
			if ($null -ne $vhddisk) {
				throw "There is already a disk with name '$UniqueName$Suffix.vhdx' attached. Detach '$($vhddisk.Location)' and retry."
			}
			if (Test-Path "$UniqueName$Suffix.vhdx") {
				throw "A file or directory with the name '$UniqueName$Suffix.vhdx' already exists. Delete and retry."
			}
		}
		if (-not [string]::IsNullOrEmpty($env:GoTestName)) {
			throw "A test environment with name ${env:GoTestName} has already been mounted. Dismount and retry."
		}
	}
	Process {
		$Suffixes = @("Guid", "Drive", "Identity", "Junction", "HardLink")
		if ($SkipVolGuid.IsPresent	) { $Suffixes = $Suffixes | where { $_ -ne "Guid" } }
		if ($SkipDrive.IsPresent	) { $Suffixes = $Suffixes | where { $_ -ne "Drive" } }
		if ($SkipIdentity.IsPresent	) { $Suffixes = $Suffixes | where { $_ -ne "Identity" } }
		if ($SkipJunction.IsPresent	) { $Suffixes = $Suffixes | where { $_ -ne "Junction" } }
		if ($SkipHardLink.IsPresent	) { $Suffixes = $Suffixes | where { $_ -ne "HardLink" } }

		$env:GoTestName=$UniqueName
		$env:GoTestRoot=$PWD.Path
		$env:GoTestSuffixes = $Suffixes -join ";"
		$env:GoTestLong1 = ("1. $UniqueName Directory ".PadRight(($script:MaxPathSegment - 3), '_') + " .1")
		$env:GoTestLong2 = ("2. $UniqueName Directory ".PadRight(($script:MaxPathSegment - 3), '_') + " .2")
		$env:GoTestLong3 = ("3. $UniqueName Directory ".PadRight(($script:MaxPathSegment - 3), '_') + " .3")
		$env:GoTestLong4 = ("4. $UniqueName File ".PadRight(($script:MaxPathSegment - 7), '_') + " .4.txt")

		$CaseSensitive = @{ CaseSensitive = $false }
		if ($EnableCaseSensitiveDirectories.IsPresent) {
			$key = Get-NtfsEnableDirCaseSensitivity
			if ($null -eq $key) {
				$env:GoTestNtfsEnableDirCaseSensitivity = "null"
				$key = 0
			} else {
				$env:GoTestNtfsEnableDirCaseSensitivity = $key
			}
			if (0 -eq (1 -band $key)) {
				Set-NtfsEnableDirCaseSensitivity (1 -bor $key)
			}
			$CaseSensitive.CaseSensitive = $true
		}

		if ($EnableLongPaths.IsPresent) {
			$key = Get-LongPathsEnabled
			if ($null -eq $key) {
				$env:GoTestLongPathsEnabled = "null"
			} else {
				$env:GoTestLongPathsEnabled = $key
			}
			if (0 -eq (1 -band $key)) {
				Set-LongPathsEnabled (1 -bor $key)
			}
		}

		New-GoPeculiarDirectory -RootPath $env:GoTestRoot @CaseSensitive
		New-GoPeculiarLinks -RootPath $env:GoTestPeculiar -TargetPath $env:GoTestPeculiar
		New-GoSmbShare "" $env:GoTestRoot
		$SharedFolder = Combine-Paths $env:GoTestPeculiar, "SmbShare"
		New-GoSmbShare "Smb" $SharedFolder
		New-GoSmbShare "SmbNoParse" $SharedFolder -NoParseDir

		Set-GoEnv -Suffix "" -Name VolId -Value "{00000000-0000-0000-0000-000000000000}"
		Set-GoEnv -Suffix "" -Name NoVol -Value "\\?\Volume{00000000-0000-0000-0000-000000000000}"
		Set-GoEnv -Suffix "" -Name NoDos -Value (Combine-Paths $env:GoTestPeculiar, "DosWasHere")
		Set-GoEnv -Suffix "" -Name NoNet -Value ("\\GONE{0:x8}\ConnectivityLost" -f @(Get-Random))
		New-Link /d (Combine-Paths $env:GoTestPeculiar, "VolMissing") $env:GoTestNoVol
		New-Link /d (Combine-Paths $env:GoTestPeculiar, "DosMissing") $env:GoTestNoDos
		New-Link /d (Combine-Paths $env:GoTestPeculiar, "NetMissing") $env:GoTestNoNet

		foreach ($Suffix in $Suffixes) {
			$AssignDriveLetter = $Suffix -eq "Drive"
			$vhd = New-GoVhd $Suffix -AssignDriveLetter:$AssignDriveLetter
			$VolPath = (dir env:"GoTestVolId$Suffix").Value
			$VolPath = "\\?\Volume$VolPath\"
			Write-Verbose "Virtual disk $Suffix has volume path $VolPath"

			$Dir = "${env:GoTestPeculiar}\$Suffix"
			switch ($Suffix) {
			"Identity" {
				New-Dir $Dir | Out-Null
				Write-Verbose "Add-PartitionAccessPath -AccessPath $Dir"
				$vhd | Get-Disk | Get-Partition | Add-PartitionAccessPath -AccessPath $Dir
			}
			"Junction" { New-Link /j "$Dir" $VolPath }
			"HardLink" { New-Link /d "$Dir" $VolPath }
			}
			# $vhd | Dismount-VHD
			# $vhd | Mount-VHD
			$vhd = Get-Vhd $vhd.Path
			$RootPath = ($vhd | Get-Disk | Get-Partition).AccessPaths[0]
			Set-GoEnv -Suffix $Suffix -Name VhdRoot -Value $RootPath -TrimEnd
			if (Test-Path $Dir -PathType Container) {
				$UsePath = $Dir
				Set-GoEnv -Suffix $Suffix -Name VhdLink -Value $Dir -TrimEnd
			} else {
				$UsePath = $RootPath
			}

			New-GoPeculiarDirectory -Suffix $Suffix -RootPath $UsePath @CaseSensitive
			New-GoPeculiarLinks -RootPath $UsePath -TargetPath (Combine-Paths $UsePath, Peculiar)
		}

		Set-Dir $PWD
	}
	End {
		Write-Host
		Write-Host "dir env:GoTest<name> - Environment variables - <name> can be used for argument substitution"
		dir env:GoTest* | sort Name
	}
}
<#
	.Synopsis
	Perform teardown steps which are about the reverse of what Mount-Go does.

	.Description
	Perform teardown steps by deleting any directory called Peculiar in the current directory
	and probing the environment for suffixes that are defined, dismounting and deleting
	all virtual disks in the current directory with matching names.

	.Parameter UniqueName
	The unique name that was previously used with Mount-Go. The default is $env:GoTestName

	.Parameter Force
	All virtual disk files ($UniqueName*.vhdx) in the current directory ($PWD.Path) will be dismounted and deleted.
#>
function Dismount-Go {
	[CmdLetBinding()]
	Param(
		[ValidateNotNullOrEmpty()][string]$UniqueName = $env:GoTestName,
		[switch]$Force = [switch]::new($false)
	)
	Begin {
		if ([string]::IsNullOrEmpty($UniqueName)) {
			throw "The UniqueName argument is null or empty. `$env:GoTestName is not defined or the explicitly specified name is invalid. Cannot teardown before setting up."
		}
		if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
			Write-Verbose "Skipping setup because the operating system is not Windows."
			return;
		}
		if ($PWD.Provider.Name -ne "FileSystem") {
			throw "Cannot run in the current PowerShell working directory. The `$PWD is from provider '$($PWD.Provider.Name)'. Change the working directory to a normal file system path then try again."
		}
		if (($PWD.Path -match "[\\\/]Peculiar([\\\/]|`$)")) {
			throw "You are in a peculiar directory here. Get out and retry."
		}
	}
	Process {
		$gcd = Get-Dir
		if ((Get-Location -PSProvider FileSystem).Path -ne $gcd) {
			Write-Verbose "gcd is $gcd; cd $PWD"
			Set-Dir $PWD.Path
		}

		if (-not [string]::IsNullOrEmpty($env:GoTestNoNet)) {
			Remove-SmbMapping -Force -ErrorAction SilentlyContinue -RemotePath $env:GoTestNoNet
		}
		$SmbShares = Get-SmbShare -Name "$UniqueName*" -ErrorAction SilentlyContinue
		foreach ($SmbShare in $SmbShares) {
			$rex = $rex = "([\\\/][\\\/]\?[\\\/]UNC)?\\\\(localhost|$([regex]::Escape($env:ComputerName)))\\$([regex]::Escape($SmbShare.Name))"
			$SmbMappings = Get-SmbMapping | where RemotePath -match $rex
			foreach ($SmbMapping in $SmbMappings) {
				Write-Verbose "Deleting SMB mapping $($SmbMapping.LocalPath) => $($SmbMapping.RemotePath)"
				$SmbMapping | Remove-SmbMapping -Force -ErrorAction Stop
			}

			Write-Verbose "Removing SMB share \\localhost\$($SmbShare.Name)"
			Remove-SmbShare -Name $SmbShare.Name -Force
		}

		$retry = 0
		while (Test-Path Peculiar) {
			Write-Verbose "Attempting to delete $PWD\Peculiar"
			$SharingViolation = [int]0x80070020
			rmdir Peculiar -Recurse -Force -ErrorAction SilentlyContinue
			if (-not (Test-Path Peculiar)) { Write-Verbose "Succeeded"; break }
			Write-Verbose "$($Error[0]) (0x$($Error[0].Exception.HResult.ToString("x8")))"
			sleep 1
			if (++$retry -eq 5) { rmdir Peculiar -Recurse -Force; return }
		}

		function TryDeleteVhd([string]$path) {
			$filename = [System.IO.Path]::GetFileName($path)
			$vhddisk = Get-Disk  |
				where BusType -Match "File Backed Virtual" |
				where { [System.IO.Path]::GetFileName($_.Location) -eq $filename }
			if ($null -ne $vhddisk) {
				if ($vhddisk.Location -ne $path) {
					throw "There is already a disk with name '$filename' attached. Its not here. Detach '$($vhddisk.Location)' and retry."
				}
				Write-Verbose "Dismounting VHD $($vhddisk.Location)"
				Dismount-Vhd $vhddisk.Location
				Write-Verbose "Deleting $($vhddisk.Location)"
				del $vhddisk.Location
			} elseif (Test-Path $path) {
				Write-Verbose "Deleting '$path'"
				del $path
			}
		}

		$Suffixes = $env:GoTestSuffixes -split ";"
		foreach ($Suffix in $Suffixes) {
			TryDeleteVhd (Combine-Paths $PWD.Path, "$UniqueName$Suffix.vhdx")
		}
		if ($Force.IsPresent) {
			dir "$UniqueName*.vhdx" | foreach {
				TryDeleteVhd $_.FullName
			}
		}

		if ($null -ne $env:GoTestNtfsEnableDirCaseSensitivity) { # if not saved, won't restore
			Write-Verbose "Attempting to restore global setting NtfsEnableDirCaseSensitivity to ${env:GoTestNtfsEnableDirCaseSensitivity}"
			if ("null" -eq $env:GoTestNtfsEnableDirCaseSensitivity) {
				Set-NtfsEnableDirCaseSensitivity $null
			} elseif ($null -ne $env:GoTestNtfsEnableDirCaseSensitivity) {
				Set-NtfsEnableDirCaseSensitivity $env:GoTestNtfsEnableDirCaseSensitivity
			}
		}
		if ($null -ne $env:GoTestLongPathsEnabled) { # if not saved, won't restore
			Write-Verbose "Attempting to restore global setting LongPathsEnabled to ${env:GoTestLongPathsEnabled}"
			if ("null" -eq $env:GoTestLongPathsEnabled) {
				Set-LongPathsEnabled $null
			} elseif ($null -ne $env:GoTestLongPathsEnabled) {
				Set-LongPathsEnabled $env:GoTestLongPathsEnabled
			}
		}
		dir "env:GOTEST*" | foreach {
			$n = $_.Name
			Write-Verbose "Deleting env:$n"
			del "env:$($_.Name)"
		}
	}
}
<#
	.Synopsis
	Defines an environment variable with a name in the format that Test-Go and related commands expect.

	.Description
	Defines a name that may appear in test case definitions, enclosed in < and >.

	The format is the concatenation of Name and Suffix. Suffix may be empty.

	.Parameter Name
	The name of the variable.

	.Parameter Suffix
	The suffix to the name of the variable.

	.Parameter value
	The value that will be set for the environment variable.

	.Parameter TrimStart
	Trim leading \ / and ? before setting the environment variable value.

	.Parameter TrimEnd
	Trim trailing \ / and ? before setting the environment variable value.
#>
function Set-GoEnv([string]$Name, [string]$Suffix, [string]$Value, [switch]$TrimStart = [switch]::new($false), [switch]$TrimEnd = [switch]::new($false)) {
	$ItemName = "GoTest$Name$Suffix"
	$ItemValue = $Value
	if ($null -ne $Value) {
		if ($TrimStart.IsPresent) {
			$ItemValue = $Value.TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar, '?')
		}
		if ($TrimEnd.IsPresent) {
			$ItemValue = $Value.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar, '?')
		}
	}
	if (Test-Path -Path "env:$ItemName") {
		Write-Verbose "Set-Item env:$ItemName=$ItemValue (Original $Value)"
		Set-Item -Path env: -Name $ItemName -Value $ItemValue | Out-Null
	} else {
		Write-Verbose "New-Item env:$ItemName=$ItemValue (Original $Value)"
		New-Item -Path env: -Name $ItemName -Value $ItemValue | Out-Null
	}
}
<#
	.Synopsis
	Calls [System.IO.Path]::Combine instead of relying on Join-Path.
#>
function Combine-Paths($a) {
	$list = [System.Collections.Generic.List[string]]::new()
	$a | foreach { if (-not [string]::IsNullOrEmpty($_)) { $list.Add($_) } }
	return [System.IO.Path]::Combine($list)
}
<#
	.Synopsis
	Calls [System.IO.Directory]::GetCurrentDirectory instead of relying on $PWD.Path.
#>
function Get-Dir { [System.IO.Directory]::GetCurrentDirectory() }
<#
	.Synopsis
	Calls [System.IO.Directory]::SetCurrentDirectory instead of relying on Set-Location (cd).
#>
function Set-Dir([string]$path) { [System.IO.Directory]::SetCurrentDirectory($path) }
<#
	.Synopsis
	Calls [System.IO.Directory]::CreateDirectory instead of relying on mkdir.
#>
function New-Dir($a) {
	$full = Combine-Paths $a
	Write-Verbose "Creating directory $full"
	[System.IO.Directory]::CreateDirectory($full)
}
<#
	.Synopsis
	Creates a very small virtual disk. For internal use by Mount-Go and Dismount-Go.
#>
function New-GoVhd {
	[CmdLetBinding()]
	Param(
		[string]$Suffix = "",
		[switch]$AssignDriveLetter = [switch]::new($false),
		[ValidateSet("NTFS", "ReFS", "FAT32", "exFAT", "FAT")]
		[string]$FileSystem = "NTFS",

		[ValidateSet("GPT", "MBR")]
		[string]$PartitionStyle = "GPT",
		[long]$VhdSize = 3MB
	)
	Process {
		$FullPath = Combine-Paths ${env:GoTestRoot}, "$UniqueName$Suffix.vhdx"

		Write-Verbose "Create virtual disk '$FullPath' size '$VhdSize'"
		$vhd = New-VHD -Path $FullPath -SizeBytes $VhdSize -Fixed -ErrorAction Stop
		Write-Verbose "Mounting virtual disk"
		$vhd | Mount-VHD
		$vhd = Get-VHD $vhd.Path # refresh to update DiskNumber, IsAttached, ..
		$disk = $vhd | Get-Disk
		Write-Verbose "Initializing disk $($disk.Number) for '$FullPath' with partition style $PartitionStyle"
		$disk | Initialize-Disk -PartitionStyle $PartitionStyle
		# $part = $vhd | Get-Disk | Get-Partition
		Write-Verbose "Create partition '$FullPath' AssignDriveLetter:`$false"
		$part = $vhd | Get-Disk | New-Partition -UseMaximumSize -AssignDriveLetter:$AssignDriveLetter
		Set-GoEnv -Suffix $Suffix -Name VolId -Value $part.Guid

		# Format as NTFS
		# $vol = $vhd | Get-Disk | Get-Partition | Get-Volume
		Write-Verbose "Formatting disk $($part.DiskNumber) partition $($part.PartitionNumber) as '$FileSystem'."
		$vol = $part | Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $UniqueName
		$volid = $vol.UniqueId # \\?\Volume{guid}
		$vhd
	}
}
<#
	.Synopsis
	Creates a peculiar directory structure. For internal use by Mount-Go and Dismount-Go.
#>
function New-GoPeculiarDirectory {
	[CmdLetBinding()]
	Param(
		[string]$Suffix,
		[string]$RootPath,
		[switch]$CaseSensitive = [switch]::new($false)
	)
	Process {
		Write-Verbose "Create peculiar directory in '$RootPath'"
		$FullPath = Combine-Paths $RootPath, "Peculiar"
		Set-GoEnv -Suffix $Suffix -Name Peculiar -Value $FullPath
		New-Dir $FullPath | Out-Null

		function CreateDir([string]$Relative) { New-Dir $FullPath, $Relative }
		function WriteFile([string]$Relative, [string]$Content) {
			$f = Combine-Paths $FullPath, $Relative
			Write-Verbose "Writing '$f', Content: $Content"
			[System.IO.File]::WriteAllText($f, $Content)
		}
		$normal = CreateDir "Normal\people\don`'t\use"
		WriteFile "Normal\people\don`'t\use\underscores.md" "# ___So we do___"
		$longname = Combine-Paths $FullPath, $env:GoTestLong1, $env:GoTestLong2, $env:GoTestLong3
		$long = CreateDir $longname
		$longfile = Combine-Paths $longname, $env:GoTestLong4
		WriteFile $longfile $longfile

		$temp = CreateDir "Docker"
		WriteFile "Docker\Dockerfile" "FROM scratch"

		if (-not $FullPath.StartsWith("\\?\")) {
			$FullPath = "\\?\$FullPath"
		}
		$temp = CreateDir "Empty"

		$temp = CreateDir "GitLike"
		$temp = CreateDir "GitLike\RepoA"
		$temp = CreateDir "GitLike\RepoA\Empty"
		$temp = CreateDir "GitLike\RepoB"
		WriteFile "GitLike\RepoB\NotEmpty.txt" "NotEmpty"
		$submodule = Combine-Paths $FullPath, "GitLike\RepoA\Submodule"
		$target = Combine-Paths $FullPath, "GitLike\RepoB"
		New-Link /d $submodule $target

		$temp = CreateDir "OneFile"
		WriteFile "OneFile\file.txt" "file"
		New-Link $null (Combine-Paths $FullPath, FileLink.txt) (Combine-Paths $FullPath, OneFile\file.txt)
		New-Link /h (Combine-Paths $FullPath, FileHardLink.txt) (Combine-Paths $FullPath, OneFile\file.txt)

		$temp = CreateDir "Container"
		$temp = CreateDir "Container\CaseSensitiveDir"
		if ($CaseSensitive.IsPresent) {
			Write-Verbose "fsutil file SetCaseSensitiveInfo $($temp.FullName) enable"
			fsutil file SetCaseSensitiveInfo $temp.FullName enable
		} else {
			Write-Verbose "Skipped: fsutil file SetCaseSensitiveInfo $($temp.FullName) enable"
		}
		WriteFile "Container\CaseSensitiveDir\file.txt" "file"
		WriteFile "Container\CaseSensitiveDir\FILE.txt" "FILE"

		$temp = CreateDir "Ordering"
		CreateDir "Ordering\a" | Out-Null
		CreateDir "Ordering\b" | Out-Null
		WriteFile "Ordering\A ."	"\u0020 space"
		WriteFile "Ordering\A!"		"\u0021 !"
		WriteFile "Ordering\A.."	"\u002f ."
		WriteFile "Ordering\A@"		"\u0040 @"
		WriteFile "Ordering\AA"		"\u0041 A"
		WriteFile "Ordering\AZ"		"\u005A Z"
		WriteFile "Ordering\A["		"\u005b ["
		WriteFile 'Ordering\A`'		'\u0060 `'
		WriteFile "Ordering\Aa ."	"\u0061 a"
		WriteFile "Ordering\Az ."	"\u007a z"
		WriteFile "Ordering\A{"		"\u007b {"
		WriteFile "Ordering\A~"		"\u007f {"
		WriteFile "Ordering\AÆ"		"\u00c6 Æ"
		WriteFile "Ordering\Aæ"		"\u00e6 æ"
		WriteFile "Ordering\AΔ"		"\u0394 Δ"
		WriteFile "Ordering\Aδ"		"\u03b4 δ"
		WriteFile "Ordering\AЖ"		"\u0416 Ж"
		WriteFile "Ordering\Aж"		"\u0436 ж"

		$temp = CreateDir "Edgy"
		WriteFile "Edgy\..." "dotdot"
		WriteFile "Edgy\...." "dotdotdot"
		WriteFile "Edgy\ " "space"
		WriteFile "Edgy\. " "dotspace"
		WriteFile "Edgy\.. " "dotdotspace"
		WriteFile "Edgy\... " "dotdotdotspace"
		WriteFile "Edgy\.txt" "ext"
		WriteFile "Edgy\..txt" "dot"
		WriteFile "Edgy\...txt" "dotdot"
		WriteFile "Edgy\....txt" "dotdotdot"
		WriteFile "Edgy\ .txt" "space"
		WriteFile "Edgy\ ..txt" "spacedot"
		WriteFile "Edgy\ ...txt" "spacedotdot"
		WriteFile "Edgy\ ....txt" "spacedotdotdot"
		WriteFile "Edgy\.txt." "dot"
		WriteFile "Edgy\.txt.." "dotdot"
		WriteFile "Edgy\.txt..." "dotdotdot"
		WriteFile "Edgy\.txt...." "dotdotdotdot"
	}
}
<#
	.Synopsis
	Creates SMB shares. For internal use by Mount-Go and Dismount-Go.
#>
function New-GoSmbShare(
	[string]$Suffix,
	[string]$TargetPath,
	[switch]$NoParseDir = [switch]::new($false),
	[switch]$NoParseRemote = [switch]::new($false),
	[switch]$UseComputerName = [switch]::new($false))
{
	Write-Verbose "Create SMB Share and Mapping"
	$ShareName = "$UniqueName$Suffix"
	if (-not (Test-Path $TargetPath)) {
		New-Dir $TargetPath | Out-Null
		[System.IO.File]::WriteAllText((Combine-Paths $TargetPath, "netfile.txt"), "netfile")
	}
	if ($NoParseDir.IsPresent -and -not $TargetPath.StartsWith("\\?\")) {
		$TargetPath = "\\?\$TargetPath"
	}
	$SmbShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
	if ($SmbShare -ne $null) { Remove-SmbShare -Name $ShareName -Confirm:$false -Force -ErrorAction SilentlyContinue }
	Write-Verbose "Creating share $ShareName => $TargetPath"
	$SmbShare = New-SmbShare -Name $ShareName -Path $TargetPath
	Set-GoEnv -Suffix $Suffix -Name Shared -Value $TargetPath -TrimDirectorySeparators

	if ($UseComputerName.IsPresent) {
		$ComputerName = $env:ComputerName
	} else {
		$ComputerName = "localhost"
	}

	$Error.Clear()
	$drives = (Get-PSDrive | where Name -Match "^\w$").Name
	foreach ($drive in ("A".."Z" | where { $drives -notcontains $_ })) {
		$SmbLocalPath = "$($drive):"
		if ($NoParseRemote.IsPresent) {
			$SmbRemotePath = "\\?\UNC\$ComputerName\$ShareName"
		} else {
			$SmbRemotePath = "\\$ComputerName\$ShareName"
		}
		$m = "SMB mapping '$SmbLocalPath' => '$SmbRemotePath'"
		Write-Verbose "Creating $m"
		$SmbMapping = New-SmbMapping -LocalPath $SmbLocalPath -RemotePath $SmbRemotePath -ErrorAction SilentlyContinue
		if ($null -eq $SmbMapping) {
			Write-Verbose "$m $($Error[0])"
			# if ($Error[0].Exception.HResult -eq 0x80131500) { throw # The network name cannot be found. }
		} else {
			Write-Verbose "Succeeded creating $m"
			Set-GoEnv -Suffix $Suffix -Name Local -Value $SmbLocalPath -TrimEnd
			Set-GoEnv -Suffix $Suffix -Name Remote -Value $SmbRemotePath -TrimEnd
			break
		}
	}
	if ($null -eq $SmbMapping) {
		foreach ($e in $Error) { Write-Error $e }
		throw "Could not create SMB mapping. There is no available drive letter."
	}
}

<#
	.Synopsis
	Passes through to Windows command mklink. For internal use by Mount-Go and Dismount-Go.
#>
function New-Link {
	[CmdLetBinding()]
	Param([string]$type, [string]$name, [string]$target)
	if ([System.IO.Directory]::Exists($target)) {
		Write-Verbose "cmd /c mklink $type $name `"$target`""
	} else {
		Write-Warning "cmd /c mklink $type $name `"$target`": Creating link to a resource that may not exist."
	}
	cmd /c mklink $type $name "`"$target`""
}
<#
	.Synopsis
	Creates links and junctions. For internal use by Mount-Go and Dismount-Go.
#>
function New-GoPeculiarLinks([string]$RootPath, [string]$TargetPath, [switch]$UseComputerName = [switch]::new($false)) {
	if ($UseComputerName.IsPresent) {
		$ComputerName = $env:ComputerName
	} else {
		$ComputerName = "localhost"
	}
	Write-Verbose "Create links, junctions and access paths in '$RootPath'"
	New-Link /d (Combine-Paths $RootPath, UncDir) "\\$ComputerName\$UniqueName"
	New-Link /d (Combine-Paths $RootPath, UncDirNoParse) "\\?\UNC\$ComputerName\$UniqueName"

	New-Link /d (Combine-Paths $RootPath, NoNetDir) "\\$ComputerName\NoNetwork$UniqueName"
	New-Link /d (Combine-Paths $RootPath, NoNetDirNoParse) "\\?\UNC\$ComputerName\NoNetwork$UniqueName"

	New-Link /j (Combine-Paths $RootPath, Long1) (Combine-Paths $TargetPath, $env:GoTestLong1)
	New-Link /j (Combine-Paths $RootPath, Long2) (Combine-Paths $TargetPath, $env:GoTestLong1, $env:GoTestLong2)
	New-Link /j (Combine-Paths $RootPath, Long3) (Combine-Paths $TargetPath, $env:GoTestLong1, $env:GoTestLong2, $env:GoTestLong3)
	New-Link /j (Combine-Paths $RootPath, Long1, Long12) (Combine-Paths $TargetPath, $env:GoTestLong1, $env:GoTestLong2)
}
<#
	.Synopsis
	Determines whether long paths are globally enabled.

	If the registry setting is not present, the result is $null.
#>
function Get-LongPathsEnabled {
	[CmdLetBinding()]
	Param()
	Process {
		try {
			Get-ItemPropertyValue `
				-Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem `
				-Name LongPathsEnabled `
				-ErrorAction SilentlyContinue
		} catch {
			$null
		}
	}
}
<#
	.Synopsis
	Writes or deletes the registry key that governs whether long paths are globally enabled.

	.Parameter Value
	If the value is $null, the registry key is deleted. The value is created or overwritten if the value can be coerced to [int].
#>
function Set-LongPathsEnabled {
	[CmdLetBinding()]
	Param($Value)
	Process {
		if ($null -eq $Value) {
			Remove-ItemProperty `
				-Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem `
				-Name LongPathsEnabled
		} else {
			Set-ItemProperty `
				-Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem `
				-Name LongPathsEnabled `
				-Value ([int]$Value)
		}
	}
}
<#
	.Synopsis
	Determines whether directories may be marked case sensitive on this machine.

	If the registry setting is not present, the result is $null.
#>
function Get-NtfsEnableDirCaseSensitivity() {
	[CmdLetBinding()]Param()
	Process {
		try {
			Get-ItemPropertyValue `
				-Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem `
				-Name NtfsEnableDirCaseSensitivity `
				-ErrorAction SilentlyContinue
		} catch {
			$null
		}
	}
}
<#
	.Synopsis
	Writes or deletes the registry key that governs whether directories may be marked case sensitive on this machine.

	.Parameter Value
	If the value is $null, the registry key is deleted. The value is created or overwritten if the value can be coerced to [int].
#>
function Set-NtfsEnableDirCaseSensitivity {
	[CmdLetBinding()]
	Param($Value)
	Process {
		if ($null -eq $Value) {
			Remove-ItemProperty `
				-Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem `
				-Name NtfsEnableDirCaseSensitivity
		} else {
			Set-ItemProperty `
				-Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem `
				-Name NtfsEnableDirCaseSensitivity `
				-Value ([int]$Value)
		}
	}
}
