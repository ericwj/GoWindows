<#
#Requires -Module VSSetup
using module VSSetup
#>
<#
	.Synopsis
	Obtain the latest installed version of Visual Studio.

	.Parameter ExcludePrerelease
	Do not allow selection of Preview versions of Visual Studio. (Passed through negated to Get-VSSetupInstance)
#>
function Get-GoFilePath {
	[CmdLetBinding()]
#	[OutputType([Microsoft.VisualStudio.Setup.Instance])]
	Param(
		[Parameter(ParameterSetName = "Abs"				)] [switch]$Abs				= [switch]::new($false),
		[Parameter(ParameterSetName = "Base"			)] [switch]$Base			= [switch]::new($false),
		[Parameter(ParameterSetName = "Clean"			)] [switch]$Clean			= [switch]::new($false),
		[Parameter(ParameterSetName = "Dir"				)] [switch]$Dir				= [switch]::new($false),
		[Parameter(ParameterSetName = "EvalSymlinks"	)] [switch]$EvalSymlinks	= [switch]::new($false),
		[Parameter(ParameterSetName = "Ext"				)] [switch]$Ext				= [switch]::new($false),
		[Parameter(ParameterSetName = "FromSlash"		)] [switch]$FromSlash		= [switch]::new($false),
		[Parameter(ParameterSetName = "Glob"			)] [switch]$Glob			= [switch]::new($false),
		[Parameter(ParameterSetName = "IsAbs"			)] [switch]$IsAbs			= [switch]::new($false),
		[Parameter(ParameterSetName = "Join"			)] [switch]$Join			= [switch]::new($false),
		[Parameter(ParameterSetName = "ListSeparator"	)] [switch]$ListSeparator	= [switch]::new($false),
		[Parameter(ParameterSetName = "Match"			)] [switch]$Match			= [switch]::new($false),
		[Parameter(ParameterSetName = "Rel"				)] [switch]$Rel				= [switch]::new($false),
		[Parameter(ParameterSetName = "Separator"		)] [switch]$Separator		= [switch]::new($false),
		[Parameter(ParameterSetName = "Split"			)] [switch]$Split			= [switch]::new($false),
		[Parameter(ParameterSetName = "SplitList"		)] [switch]$SplitList		= [switch]::new($false),
		[Parameter(ParameterSetName = "ToSlash"			)] [switch]$ToSlash			= [switch]::new($false),
		[Parameter(ParameterSetName = "VolumeName"		)] [switch]$VolumeName		= [switch]::new($false),
		[Parameter(ParameterSetName = "Walk"			)] [switch]$Walk			= [switch]::new($false),

		[Parameter(Mandatory = $true, ParameterSetName = "Abs"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "Base"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "Clean"			, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "Dir"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "Ext"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "EvalSymlinks"		, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "FromSlash"		, ValueFromPipelineByPropertyName  = $true, Position = 1)]
#		[Parameter(Mandatory = $true, ParameterSetName = "Glob"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "IsAbs"			, ValueFromPipelineByPropertyName  = $true, Position = 1)]
#		[Parameter(Mandatory = $true, ParameterSetName = "Join"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
#		[Parameter(Mandatory = $true, ParameterSetName = "ListSeparator"	, ValueFromPipelineByPropertyName  = $true, Position = 1)]
#		[Parameter(Mandatory = $true, ParameterSetName = "Match"			, ValueFromPipelineByPropertyName  = $true, Position = 1)]
#		[Parameter(Mandatory = $true, ParameterSetName = "Rel"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
#		[Parameter(Mandatory = $true, ParameterSetName = "Separator"		, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "Split"			, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "SplitList"		, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "ToSlash"			, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "VolumeName"		, ValueFromPipelineByPropertyName  = $true, Position = 1)]
#		[Parameter(Mandatory = $true, ParameterSetName = "Walk"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[AllowNull()][AllowEmptyString()][string]$Path,

		[Parameter(Mandatory = $true, ParameterSetName = "Join"				, ValueFromPipelineByPropertyName  = $true, Position = 1, ValueFromRemainingArguments = $true)]
		[AllowNull()][AllowEmptyCollection()][string[]]$Elements,
		[Parameter(Mandatory = $true, ParameterSetName = "Glob"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "Match"			, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[AllowNull()][AllowEmptyString()][string]$Pattern,
		[Parameter(Mandatory = $true, ParameterSetName = "Match"			, ValueFromPipelineByPropertyName  = $true, Position = 2)]
		[AllowNull()][AllowEmptyString()][string]$Name,
		[Parameter(Mandatory = $true, ParameterSetName = "Rel"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[AllowNull()][AllowEmptyString()][string]$BasePath,
		[Parameter(Mandatory = $true, ParameterSetName = "Rel"				, ValueFromPipelineByPropertyName  = $true, Position = 2)]
		[AllowNull()][AllowEmptyString()][string]$TargetPath,
		[Parameter(Mandatory = $true, ParameterSetName = "Walk"				, ValueFromPipelineByPropertyName  = $true, Position = 1)]
		[AllowNull()][AllowEmptyString()][string]$Root,

		[Parameter(Mandatory = $false)]
		[AllowNull()][AllowEmptyString()][string]$UseGoApiExecutable = ".\api.exe"
	)
	Begin {
		if (![string]::IsNullOrEmpty($UseGoApiExecutable) -and (Test-Path $UseGoApiExecutable -PathType Leaf)) {
			$Exe = $UseGoApiExecutable
		} else {
			$ExeName = "api.exe"
			Write-Verbose "Looking for '$ExeName' on the path since '$ApiExe' is null, empty, or does not exist."
			$Exe = where.exe $ExeName *> $null
			$ExeOke = ![string]::IsNullOrEmpty($Exe) -and (Test-Path $Exe -PathType Leaf)
			Write-Verbose "where $ExeName returned $($LASTEXITCODE): '$Exe' (File Exists: $ExeOke)"
			if (-not $ExeOke) {
				Write-Verbose "Looking for '$ExeName' in the current working directory '$PWD' since it was not found on the path."
				$Exe = dir $ExeName -Recurse -File | select -First 1
			}
			if ($null -eq $Exe) {
				Write-Error -Message "'$ExeName' was not found on the path or under '$PWD'."
			}
			Write-Verbose "Using '$Exe'."
		}
	}
	Process {
		$Object = @{
			Api = "filepath." + $PSCmdLet.ParameterSetName
		}
		$HasPath = @(
			"Separator"
			"ListSeparator"
			"Abs"
			"EvalSymlinks"
#			"Glob"
#			"Match"
#			"Rel"
			"Base"
			"Clean"
			"Dir"
			"Ext"
			"FromSlash"
			"IsAbs"
#			"Join"
			"SplitList"
			"ToSlash"
			"VolumeName"
			"Split"
#			"Walk"
		) -contains $PSCmdLet.ParameterSetName
		Write-Verbose "HasPath: $HasPath"

		switch ($PSCmdLet.ParameterSetName) {
			"Glob"	{ $Object.Pattern = $Pattern }
			"Match"	{ $Object.Pattern = $Pattern; $Object.Path = $Name }
			"Rel"	{ $Object.Path = $BasePath; $Object.Path2 = $TargetPath }
			"Join"	{ $Object.Join = $Elements }
			"Walk"	{ $Object.Path = $Root }
		}
		$Json = ($Object | ConvertTo-Json) -split $([Environment]::NewLine) -join ""
		Write-Verbose "In-Json: $Json"
		if ($PSCmdLet.ParameterSetName -ne "Walk") {
			$Out = $Json | & $Exe
			Write-Verbose "Out-Json: $Out"
			$Result = [pscustomobject]($Out | ConvertFrom-Json)
			Write-Output $Result
		} else {
			$Json | & $Exe | foreach {
				Write-Verbose "Out-Json: $_"
				$Result = [pscustomobject]($_ | ConvertFrom-Json)
				Write-Output $Result
			}
		}
		if ($LASTEXITCODE -ne 0) {
			Write-Error "'$Exe' failed with exit code $LASTEXITCODE."
		}
	}
}
