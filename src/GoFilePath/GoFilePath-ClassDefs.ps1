class GoPaths {
	[string]$UniqueName
	[string]$VhdFile
	[Microsoft.Vhd.PowerShell.VirtualHardDisk]$Vhd
	[Microsoft.Management.Infrastructure.CimInstance]$Partition
	[Microsoft.Management.Infrastructure.CimInstance]$Volume
	[string]$VolumePath

	[int]$Count
	[System.Management.Automation.PathInfo]$PWD
	[string]$NormalPathsRoot
	[string]$ShortPathsRoot
	[string]$LongPathsRoot
	[string[]]$ShortPaths
	[string[]]$LongPaths

	[string[]]$UncPaths
	[string[]]$SmbShareNames
	[Microsoft.Management.Infrastructure.CimInstance[]]$SmbShares
	[Microsoft.Management.Infrastructure.CimInstance[]]$SmbMappings
	[string[]]$Junctions
}
