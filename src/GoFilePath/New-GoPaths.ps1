#Requires -RunAsAdministrator
#Requires -Version 5
#Requires -Module @{ ModuleName = "Hyper-V"; ModuleVersion = "2.0.0.0"; Guid = "af4bddd0-8583-4ff2-84b2-a33f5c8de8a7" }

<#
	.Synopsis
	Sets up a test environment to run go API against.
#>
function New-GoPaths {
	[CmdLetBinding()]
	[OutputType([GoPaths])]
	Param(
		[ValidateNotNullOrEmpty()]
		[ValidateLength(1, 14)]
		[ValidatePattern("\w+")]
		[string]$UniqueName = "GoFilePath",

		[ValidateSet("NTFS", "ReFS", "FAT32", "exFAT", "FAT")]
		[string]$FileSystem = "NTFS",

		[ValidateSet("GPT", "MBR")]
		[string]$PartitionStyle = "GPT",

		[switch]$AssignDriveLetter = [switch]::new($false),
		[int]$MaxPathSegment = 260 - 5,
		[long]$VhdSize = 3MB
	)
	Process {
		if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
			Write-Verbose "Skipping setup because the operating system is not Windows."
			return;
		}
		if ($PWD.Provider.Name -ne "FileSystem") {
			Write-Error "Cannot run in the current PowerShell working directory. The `$PWD is from provider '$($PWD.Provider.Name)'. Change the working directory to a normal file system path then try again."
		}
		$result = [GoPaths]::new()
		$result.UniqueName = $UniqueName
		$result.Count = 3
		$result.PWD = $PWD

		# Create virtual disk
		$result.VhdFile = [System.IO.Path]::Combine($PWD.Path, "$UniqueName.vhdx")
		if ([System.IO.File]::Exists($result.VhdFile)) {
			Write-Error "Cannot create '$($result.VhdFile)' because the file already exists. Choose a different unique name or delete the existing one with 'Delete-GoPaths' before creating one with the same name. Creating one with the same name in another directory might only replace this error with a different one."
			return
		}
		Write-Verbose "Create virtual disk '$($result.VhdFile)' size '$VhdSize'"
		$vhd = New-VHD -Path $result.VhdFile -SizeBytes $VhdSize -Fixed -ErrorAction Stop
		Write-Verbose "Mounting virtual disk"
		$vhd | Mount-VHD
		$vhd = Get-VHD $vhd.Path # refresh to update DiskNumber, IsAttached, ..
		$result.Vhd = $vhd

		Write-Verbose "Initializing '$($result.VhdFile)' with partition style $PartitionStyle"
		$vhd | Get-Disk | Initialize-Disk -PartitionStyle $PartitionStyle
		# $part = $vhd | Get-Disk | Get-Partition
		Write-Verbose "Create partition '$($result.VhdFile)' AssignDriveLetter:$AssignDriveLetter"
		$part = $vhd | Get-Disk | New-Partition -UseMaximumSize -AssignDriveLetter:$AssignDriveLetter
		$result.Partition = $part

		# Format as NTFS
		# $vol = $vhd | Get-Disk | Get-Partition | Get-Volume
		Write-Verbose "Formatting disk $($part.DiskNumber) partition $($part.PartitionNumber) as '$FileSystem'."
		$vol = $part | Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $UniqueName
		$result.Volume = $vol
		$result.VolumePath = $vol.UniqueId
		$volid = $vol.UniqueId # \\?\Volume{guid}

		$hex = "0123456789abcdef"
		$format = " " + $UniqueName.PadRight(14, '_') # 15 total

		# Create directories like normal people do - also make sure the root directory is 'Normal'
		$dir = [System.IO.FileInfo]::new([System.IO.Path]::Combine($volid, "Normal"))
		$result.NormalPathsRoot = $dir.FullName
		$full = [System.IO.Path]::Combine("people don't use underscores.txt" -split " ")
		$full = [System.IO.Path]::Combine($dir.FullName, $volid, $full)
		$path = [System.IO.Path]::GetDirectoryName($full)
		Write-Verbose "Creating directory '$path'."
		$dump = [System.IO.Directory]::CreateDirectory($path)
		Write-Verbose "Creating file '$full'."
		[System.IO.File]::WriteAllText($full, "So we do: ".PadRight(1024, '_'))

		# Create directories with short paths (not long)
		$dir = [System.IO.FileInfo]::new([System.IO.Path]::Combine($volid, "Short"))
		$result.ShortPathsRoot = $dir.FullName
		$names = 1..$result.Count | foreach {
			$name = "$_" + $format
			$full = [System.IO.Path]::Combine($dir.Fullname, $name)
			Write-Verbose "Creating directory '$full'."
			$dir = [System.IO.Directory]::CreateDirectory($full)
			$dir.Fullname
		}
		$result.ShortPaths = $names

		# Create directories with long paths
		$dir = [System.IO.FileInfo]::new([System.IO.Path]::Combine($volid, "Long"))
		$result.LongPathsRoot = $dir.FullName
		$names = 1..$result.Count | foreach {
			$name = ("$_" + $format).PadRight($MaxPathSegment, '_').ToCharArray()
			# make these very long names slightly comprehensible, tag each 16th char
			$h = 1
			for ($i = 16; $i -lt $name.Length; $i += 16) { $name[$i] = $hex[$h++] }
			# put UniqueName just before the last character and force that to be '†'
			$b = $name.Length - 1
			$name[$b] = [char]0x2020
			$b -= $UniqueName.Length
			[Array]::Copy($UniqueName.ToCharArray(), 0, $name, $b, $UniqueName.Length)
			$name = [string]::new($name)
			$full = [System.IO.Path]::Combine($dir.Fullname, $name)
			Write-Verbose "Creating directory '$full'."
			$dir = [System.IO.Directory]::CreateDirectory($full)
			$dir.Fullname
		}
		$result.LongPaths = $names

		# Create files
		$names = $result.NormalPaths + $result.ShortPaths + $result.LongPaths
		$ext = '.txt'
		foreach ($name in $names) {
			$base = [System.IO.Path]::GetFileName($name)
			Write-Verbose "Attempting to create '$base' in '$name'."
			if ($base.Length + $ext.Length -gt $MaxPathSegment) {
				$base = $base.Substring(0, $base.Length - $ext.Length)
			}
			$base = [System.IO.Path]::ChangeExtension($base, $ext)
			$full = [System.IO.Path]::Combine($name, $base)
			Write-Verbose "Writing '$base' full path '$full'"
			[System.IO.File]::WriteAllText($full, $name)
		}

		# Create network shares mapping to each of the long path names
		$result.SmbShares 		= [Microsoft.Management.Infrastructure.CimInstance[]]::new($result.Count)
		$result.SmbShareNames 	= [Microsoft.Management.Infrastructure.CimInstance[]]::new($result.Count)
		$result.UncPaths 		= [string[]]::new(3)
		$shares = 1..$result.Count | foreach {
			$i = $_ - 1
			$path = $result.LongPaths[$i]
			$name = "$UniqueName$_"
			$unc = "\\$($env:COMPUTERNAME)\$name"
			$share = Get-SmbShare -Name $name -ErrorAction SilentlyContinue
			if ($null -ne $share) {
				Write-Error "Share '$unc' already exists. Using the existing share. Have a good yesterday if this is a live machine."
			} else {
				Write-Verbose "Creating '$unc' share '$name' to '$path'."
				$share = New-SmbShare -Name $name -Path $path
			}
			$result.SmbShares[$i] = $share
			$result.SmbShareNames[$i] = $name
			$result.UncPaths[$i] = $unc
		}

<#
		# Map the network shares to a drive letter
		$mappings = 1..$result.Count | foreach {
			$map = $null;
			$unc = $result.UncPaths[$_ - 1]
			$letters = (Get-PSDrive).Name -match '^[a-z]$'
			foreach ($available in ('Z'..'A' | where { $letters -NotContains $_ })) {
				$Error.Clear()
				$dos = "$($available):"
				Write-Verbose "Attempting to create SMB mapping '$dos' to '$unc'."
				$map = New-SmbMapping -LocalPath $dos -RemotePath $unc -ErrorAction SilentlyContinue
				if ($Error.Count -eq 0) {
					break;
				} else {
					$e = $Error[0]
					Write-Warning "Could not map '$unc' to '$dos'. $($Error.FullyQualifiedErrorId): $($Error.Exception.Message)"
					Write-Verbose $e.InvocationInfo.PositionMessage
				}
			}
			if ($null -eq $map -or $map.LocalPath -ne $dos) {
				Write-Error "Unable to map any drive ltter to $unc. Is there no drive letter available?"
			}
			$map
		}
		$result.SmbMappings = $mappings

		$result.Junctions = 1..$result.Count | foreach {
			$i = $_ - 1
			$name = "Junction" + $result.ShareNames[$i]
			$to = $result.LongPaths[$i]
			Write-Verbose "Creating junction '$name' to '$to'."
			$out = & cmd /c mklink $name $to *>&1
			if ($LastExitCode -ne 0) {
				Write-Warning "Failed to create junction '$name' => '$to'. 'mklink' failed with exit code $($LastExitCode): $out"
			}
			[System.IO.Path]::Combine($PWD, $name)
		}
#>
		return $result
	}
}
