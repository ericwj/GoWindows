$script:SilentlyContinue = [System.Management.Automation.ActionPreference]::SilentlyContinue
$script:NotImplementedHResult = [System.NotImplementedException]::new().HResult
$script:InvalidChars = ([System.IO.Path]::GetInvalidFileNameChars() + [System.IO.Path]::GetInvalidFileNameChars()) | select -Unique

<#
	.Synopsis
	Stop api.exe and/or epi.exe processes. If no arguments are given, both are stopped.

	.Description
	PowerShell may not always close the input stream when piping, for example when pressing Ctrl+C.

	This command stops all processes called api.exe or epi.exe that remain running using the PowerShell Stop-Process cmdlet.

	.Parameter Api
	Stop any 'api.exe' processes.

	.Parameter Epi
	Stop any 'epi.exe' processes.
#>
function Stop-Go {
	[CmdLetBinding(SupportsShouldProcess = $true)]
	Param(
		[switch]$Api = [switch]::new($false),
		[switch]$Epi = [switch]::new($false)
	)
	Begin {
		if (-not $Api.IsPresent -and -not $Epi.IsPresent) {
			$Api = [switch]::Present
			$Epi = [switch]::Present
		}
	}
	Process {
		$Stop = $null
		if ($Api.IsPresent) { $Stop += Get-Process -Name api.exe -ErrorAction SilentlyContinue }
		if ($Epi.IsPresent) { $Stop += Get-Process -Name epi.exe -ErrorAction SilentlyContinue }
		$Stop = $Stop | sort Name, Id
		if ($null -ne $Stop) { $Stop | Stop-Process }
		$Stop
	}
}
<#
	.Synopsis
	Clears test result files from the current directory by matching against existing .csv files.

	.Parameter KeepResults
	Keeps *.results.html/json - these are deleted by default.

	.Parameter KeepFailures
	Keeps *.failures.html/json - these are deleted by default.

	.Parameter KeepHtml
	Keeps *.html - these are deleted by default.

	.Parameter KeepActual
	Keeps *.actual.html/json - these are deleted by default.

	.Parameter DeleteExpected
	Delete *.expected.json - these are kept by default.

	.Parameter DeleteInputJson
	Delete *.json - these are kept by default.
#>
function Clear-Go {
	[CmdLetBinding(SupportsShouldProcess = $true)]
	Param(
		[switch]$KeepResults		=  [switch]::new($false),
		[switch]$KeepFailures		=  [switch]::new($false),
		[switch]$KeepActual			= [switch]::new($false),
		[switch]$DeleteExpected		= [switch]::new($false),
		[switch]$DeleteInputJson	= [switch]::new($false),
		[switch]$KeepHtml			=  [switch]::new($false)
	)
	Process {
		$candidates = dir *.csv
		function GetFiIfExists {
			[CmdLetBinding()]
			Param(
				[Parameter(ValueFromPipeline = $true)][string]$path,
				[string]$ext
			)
			Begin {
				$root = (Get-Location -PSProvider FileSystem).Path
			}
			Process {
				$changed = [System.IO.Path]::ChangeExtension($path, $ext)
				$existing = dir $changed -ErrorAction SilentlyContinue
				if ($null -ne $existing) {
					Write-Verbose "Deleting '$existing'."
					$existing
				}
			}
		}
		[object[]]$results = $null
		if (-not $KeepHtml.IsPresent) {
			$results += $candidates | GetFiIfExists -ext .html
			if (-not $KeepResults.IsPresent) { $results += $candidates | GetFiIfExists -ext .results.html }
			if (-not $KeepFailures.IsPresent) { $results += $candidates | GetFiIfExists -ext  .failures.html }
		}
		if ($DeleteInputJson.IsPresent) { $results += $candidates | GetFiIfExists -ext .json }
		if ($DeleteExpected.IsPresent) { $results += $candidates | GetFiIfExists -ext  .expected.json }
		if (-not $KeepActual.IsPresent) { $results += $candidates | GetFiIfExists -ext .actual.json }
		if (-not $KeepResults.IsPresent) { $results += $candidates | GetFiIfExists -ext .results.json }
		if (-not $KeepFailures.IsPresent) { $results += $candidates | GetFiIfExists -ext  .failures.json }

		if ($null -ne $results -and $results.Length -gt 0) {
			if ($WhatIfPreference) {
				Write-Host "The following files were found and would be deleted:`n"
			} else {
				Write-Host "The following files were found and deleted:"
			}
			$results = $results | sort FullName
			$results | del
			$results
		}
	}
}
<#
	.Synopsis
	Run tests in a tab-separated file and writes several result files.

	.Description
	Runs all tests in the specified tab-separated file (file.tsv) and writes files with appended or replaced extensions with the results.

	The result files are JSON for expected and actual test results and both JSON and HTML for all tests and failed tests only.

	This command requires the go API test runner `api.exe` to be on the path.

	.Parameter InFile
	The name of the input file, containing tab-separated test data. See Read-Go for help about the file format.

	.Parameter StripDefaults
	Suppresses writing the defaults `null` for strings and arrays, `0` for numbers and `false` for booleans to JSON output files.
	Writing these values may be required to ensure that the correct columns appear when importing the data in PowerShell or exporting data to HTML.

	.Parameter GenerateExpected
	Rewrites `file.expected.json`. This requires the C# test runner `epi.exe` to be on the path. The default is not to rewrite the file.

	.Parameter RemainingArguments
	Accepts named arguments that can be used to substitute parameters in the test data. See Read-Go for help.

	.Parameter JitDebug
	Adds `--debug` as argument to `api.exe` and `epi.exe` invocations. This may or may not have any effect.

	.Parameter Encoding
	Allows overriding the default encoding. The default is UTF-8 without byte order mark.

	.Inputs
	None.

	Reads from `file.csv` or a file with any name containing tab-separated data in the correct format.

	Expects `api.exe` to be on the path.
	If GenerateExpected is present, expects `epi.exe` to be on the path.

	Having these files in the current working directory is not enough.

	.Outputs
	None.
	Writes test input data after import in JSON format to `file.json`.
	Writes actual test results to `file.actual.json`.
	May write expected test results to `file.expected.json` if the -GenerateExpected switch is present.
	Writes all joined test results and failure status to `file.results.json` and `file.results.html`.
	Writes joined test results and failure status of only failed tests to `file.failures.json` and `file.failures.html`.

	Any files written will be written to the same directory as `file.tsv` was read from.
#>
function Test-Go {
	[CmdLetBinding()]
	Param(
		[ValidateNotNull()][string]$InFile,

		[switch]$StripDefaults = [switch]::new($false),
		[switch]$GenerateExpected = [switch]::new($false),
		[switch]$JitDebug = [switch]::new($false),

		[Parameter(ValueFromRemainingArguments = $true)]$RemainingArguments
	)
	Begin {
		if ("FileSystem" -ne $PWD.Provider.Name) {
			throw [System.InvalidOperationException]::new("Cannot read or write files from PSProvider '$($PWD.Provider.Name)'. Use cd to switch to the filesystem.")
		}
		function Find-File([string]$Name) {
			where.exe $Name *> $null
			return $LastExitCode -eq 0
		}
		if (-not (Find-File api.exe)) {
			throw "'api.exe' is not on the path. Run: `$env:Path += `";`" + `"<path-to-api.exe>`""
		}
		if ($GenerateExpected.IsPresent -and -not (Find-File epi.exe)) {
			throw "'epi.exe' is not on the path. Run: `$env:Path += `";`" + `"<path-to-epi.exe>`""
		}
	}
	Process {
		$Encoding = [System.Text.Encoding]::Default
		$state = [pscustomobject][ordered]@{
			id = Get-Random
			step = 0
			max = 11
			pct = 0
			count = 0
		}
		function progress {
			Param($state, $operation, [switch]$completed = [switch]::new($false))
			Process {
				$state.pct = 100.0 / $state.max * $state.step
				Write-Progress -Id ($state.id) -Activity "Testing Go ($($state.count) tests)" `
					-PercentComplete $state.pct -Status $operation -Completed:$completed
				$state.step++
				[System.Threading.Thread]::Sleep(100)
			}
		}
		progress $state "Processing arguments"

		$ApiArgs = [System.Collections.Generic.List[string]]::new()
		if ($JitDebug.IsPresent) {
			$ApiArgs.Add("--debug")
		}
		
		function StripConditional([object]$in) {
			if ($StripDefaults.IsPresent) { return Remove-GoNulls $in -EmptyStrings -EmptyArrays } else { return $in }
		}
		function PassThrough {
			[CmdLetBinding()]
			Param(
				[Parameter(ValueFromPipeline = $true)]$InputObject,
				[string]$what,
				[switch]$json = [switch]::new($false),
				[string]$Preference = "Verbose"
			)
			Process {
				if ($json.IsPresent) {
					$Result = $InputObject | ConvertTo-Json -Compress
				} else {
					$Result = $InputObject
				}
				if (("Verbose" -eq $Preference -and $VerbosePreference -ne $script:SilentlyContinue) `
					-or `
					("Debug" -eq $Preference -and $DebugPreference -ne $script:SilentlyContinue)) {
					$idx = $InputObject.Index
					if ($null -eq $idx) { $idx = "     " } else { $idx = "#" + $idx.ToString("0000") }
					$msg = ("{0} {1,-6}: {2}" -f @($idx, $what, $Result))
					if ("Verbose" -eq $Preference) { Write-Verbose $msg }
					if ("Debug" -eq $Preference) { Write-Debug $msg }
				}
				$Result
			}
		}
		function RedirectToProcess {
			[CmdLetBinding()]
			Param(
				[Parameter(ValueFromPipeline = $true)][string]$InputObject,
				[string]$FilePath,
				[string[]]$Arguments,
				[System.Text.Encoding]$Encoding
			)
			Begin {
				$Argument = ($Arguments -join " ")
				$Preamble = $Encoding.GetPreamble()
				$Preamble = "byte[$($Preamble.Length)] = [$(($Preamble | foreach { $_.ToString("x2") }) -join ",")]"
				Write-Verbose "Starting '$FilePath' with arguments '$Argument' using encoding '$($Encoding.EncodingName)' with preamble: $Preamble."

				$psi = [System.Diagnostics.ProcessStartInfo]::new($FilePath, $Argument)
				$psi.CreateNoWindow = $true
				$psi.LoadUserProfile = $false
				$psi.RedirectStandardInput = $true
				$psi.RedirectStandardOutput = $true
				$psi.StandardInputEncoding = $Encoding
				$psi.StandardOutputEncoding = $Encoding
				$psi.UseShellExecute = $false
				$psi.WorkingDirectory = $PWD.Path
				$process = [System.Diagnostics.Process]::Start($psi)
				$in = $process.StandardInput
				$out = $process.StandardOutput
				Write-Verbose ("{0}: Started #{1} Exited: {2}, ExitCode: {3}" -f @($FilePath, $process.Id, $process.HasExited, $process.ExitCode))
			}
			Process {
				$in.WriteLine($InputObject)
				while ($true) {
					$line = $out.ReadLine()
					$line
					if ($line -notmatch "IsWalk|IsItem") { break }
				}
			}
			End {
				$in.Close()
				$process.WaitForExit()
				Write-Verbose ("{0}: Exited #{1} Exited: {2}, ExitCode: {3}" -f @($FilePath, $process.Id, $process.HasExited, $process.ExitCode))
			}
		}
		$Parameters = Splat -RemainingArguments $RemainingArguments
		$ActualFile = [System.IO.Path]::ChangeExtension($InFile, ".actual.json")
		$ExpectedFile = [System.IO.Path]::ChangeExtension($InFile, ".expected.json")

		$VPref = @{ Preference = "Verbose" }
		$DPref = @{ Preference = "Debug" }
		progress $state "Determining test count"
		$state.count = (Get-Content $InFile | measure).Count
		progress $state "Importing test definitions"
		$TestData = Read-Go -InFile $InFile @Parameters
		progress $state "Writing test cases as JSON"
		$TestData | foreach { $_ | ConvertTo-Json -Compress } | Out-File ([System.IO.Path]::ChangeExtension($InFile, ".json"))
		progress $state "Generating expected outcomes"
		if ($GenerateExpected.IsPresent) {
			if ($UsePowerShell.IsPresent) {
				$TestData | PassThrough -what "ExIn" -json @DPref | epi.exe $ApiArgs | PassThrough -what "ExOut" @DPref | Out-File $ExpectedFile
			} else {
				$TestData | PassThrough -what "ExIn" -json @DPref | RedirectToProcess -FilePath epi.exe -Arguments $ApiArgs -Encoding $Encoding | PassThrough -what "ExOut" @DPref | Out-File $ExpectedFile -Encoding $Encoding
			}
		}
		progress $state "Running tests"
		if ($UsePowerShell.IsPresent) {
			$TestData | PassThrough -what "AcIn" -json @DPref | api.exe $ApiArgs | PassThrough -what "AcOut" @DPref | Out-File $ActualFile
		} else {
			$TestData | PassThrough -what "AcIn" -json @DPref | RedirectToProcess -FilePath api.exe -Arguments $ApiArgs -Encoding $Encoding | PassThrough -what "AcOut" @DPref | Out-File $ActualFile -Encoding $Encoding
		}
		progress $state "Determining test outcomes"
		$Results = $TestData | Join-Go -ExpectedJsonFile $ExpectedFile -ActualJsonFile $ActualFile -StripDefaults:$false

		progress $state "Writing results as JSON"
		$Results | foreach { StripConditional($_) } | ConvertTo-Json | Out-File ([System.IO.Path]::ChangeExtension($InFile, ".results.json"))
		progress $state "Writing failures as JSON"
		$Results | foreach { StripConditional($_) } | where Failure | ConvertTo-Json | Out-File ([System.IO.Path]::ChangeExtension($InFile, ".failures.json"))

		progress $state "Writing results as HTML"
		$Results | Undo-GoEnumerables | ConvertTo-Html -Fragment | Redo-GoHtml | Out-File ([System.IO.Path]::ChangeExtension($InFile, ".results.html"))
		progress $state "Writing failures as HTML"
		$Results | where Failure | Undo-GoEnumerables | ConvertTo-Html -Fragment | Redo-GoHtml | Out-File ([System.IO.Path]::ChangeExtension($InFile, ".failures.html"))
		progress $state "Done" -Completed
	}
}
<#
	.Synopsis
	Joins test input data with expected and actual test results and determines whether tests failed or succeeded.

	.Description
	Accepts piped input of the format produced by Read-Go and two JSON files which are joined to a single output record per input. Reading of the JSON files is done line-by-line. Each line should contain exactly one test result.

	The JSON files have the same format and should contain one valid JSON document per line. See full help for details.

	.Parameter InputObject
	Pipeline input of objects with named properties or PowerShell hashtables (@{Name=Value}).

	.Parameter ExpectedJsonFile
	The path of the file containing expected test results in the JSON format described in the description of this command.

	.Parameter ActualJsonFile
	The path of the file containing actual test results in the JSON format described in the description of this command.

	.Inputs
	The properties expected on the objects in the pipeline input are Api, Path, Path2, Pattern, Join, Traits and/or Index.
	Applicable properties are required. Trait and Index simply pass through.

	The JSON files should have the properties: Errno, Result, Name, Error. Applicable properties are required.
	* Errno should be an integer.
	* Result can be a string or an array of strings.
	* Name and Error are strings.

	See api.go for more information.

	.Outputs
	A single object per combination of test input data, expected test result and actual test result.

	The object has the following properties, all of which are string unless specified: Failure (bool), Api,
	ExErrno (int), AcErrno (int), ExResult (string or string[]), AcResult (string or string[]), ExName, AcName,
	ExError, AcError, Path, Path2, Pattern, Join (string[]), Traits (string[]), Index (int).
	* Failure indicates whether the test failed.
	* ExXxx is the expected value.
	* AcXxx is the actual value.
	* Traits are the traits from the input file.
	* Index is a sequential number.
#>
function Join-Go {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true)]$InputObject,
		[ValidateNotNullOrEmpty()][string]$ExpectedJsonFile,
		[ValidateNotNullOrEmpty()][string]$ActualJsonFile,
		[switch]$StripDefaults = [switch]::new($false),
		[Parameter(ValueFromRemainingArguments = $true)]$RemainingArguments
	)
	Begin {
		if ("FileSystem" -ne $PWD.Provider.Name) {
			throw [System.InvalidOperationException]::new("Cannot read or write files from PSProvider '$($PWD.Provider.Name)'. Use cd to switch to the filesystem.")
		}
		$ExpectedJsonPath = [System.IO.Path]::GetFullPath($ExpectedJsonFile, $PWD.Path)
		$ActualJsonPath = [System.IO.Path]::GetFullPath($ActualJsonFile, $PWD.Path)

		if ($DebugPreference -ne $script:SilentlyContinue) {
			Write-Debug "Expected: $([System.IO.File]::ReadAllLines($ExpectedJsonPath).Length), Actual: $([System.IO.File]::ReadAllLines($ActualJsonPath).Length)"
		}

		Write-Verbose "Opening $ExpectedJsonPath"
		$efile = [System.IO.File]::OpenText($ExpectedJsonPath)

		Write-Verbose "Opening $ActualJsonPath"
		$afile = [System.IO.File]::OpenText($ActualJsonPath)

		$index = 1

		function DisposeFiles() {
			if ($null -ne $afile) {
				Write-Verbose "Closing $ExpectedJsonPath"
				$afile.Close()
				$afile = $null
			}
			if ($null -ne $efile) {
				Write-Verbose "Closing $ActualJsonPath"
				$efile.Close()
				$efile = $null
			}
		}
	}
	End {
		DisposeFiles
	}
	Process {
		$count = 0
		$expectedIsDone = $false
		$actualIsDone = $false
		try {
			while ($true) {
				Write-Debug ("#{0:0000} ExpectedDone: {1}, ActualDone: {2}" -f @($count, $expectedIsDone, $actualIsDone))
				if ($expectedIsDone) {
					$expected = $null
				} else {
					$expected = $efile.ReadLine()
					if ($null -eq $expected) {
						throw "End of stream reading expected value for $InputObject"
						return
					} else {
						try {
							$expected = $expected | ConvertFrom-Json
							if (-not [bool]$expected.IsItem) { $expectedIsDone = $true }
						} catch {
							Write-Warning "Failed to deserialize expected JSON '$expected'"
							throw
						}
					}
				}
				if ($actualIsDone) {
					$actual = $null
				} else {
					$actual = $afile.ReadLine()
					if ($null -eq $actual) {
						throw "End of stream reading actual value for $InputObject"
						return
					} else {
						try {
							$actual = $actual | ConvertFrom-Json
							if (-not [bool]$actual.IsWalk) { $actualIsDone = $true }
						} catch {
							Write-Warning "Failed to deserialize actual JSON '$actual'"
							throw
						}
					}
				}

				$Result = [ordered]@{
					Failure		= $false
					Api			= $InputObject.Api
					ExErrno		= [System.Nullable[int]]$expected.Errno
					AcErrno		= [System.Nullable[int]]$actual.Errno
					ExResult	= $expected.Result
					AcResult	= $actual.Result
					ExName		= $expected.Name
					AcName		= $actual.Name
					ExError		= $expected.Error
					AcError		= $actual.Error
					ExIsItem	= [System.Nullable[bool]]$expected.IsItem
					AcIsItem	= [System.Nullable[bool]]$actual.IsWalk
					Path		= $InputObject.Path
					Path2		= $InputObject.Path2
					Pattern		= $InputObject.Pattern
					Join		= $InputObject.Join
					Traits		= $InputObject.Traits
					Index		= $InputObject.Index
					Target		= $InputObject.Target
					LinkType	= $InputObject.LinkType
				}
#				if ($InputObject.Join -is [string[]]) {
#					if ($InputObject.Join.Length -eq 0) {
#						$Result.Join
#					} else {
#						$Result.Join = [string]::Join(";", $InputObject.Join)
#					}
#				}
#				if ($InputObject.Traits -is [string[]] -and $InputObject.Traits.Length -ne 0) {
#					$Result.Traits = [string]::Join(",", $InputObject.Traits)
#				}
				if ($DebugPreference -ne $script:SilentlyContinue) {
					Write-Debug ("Processing #{0:0000} {1}" -f @($index, $InputObject))
					Write-Debug ("Expected   #{0:0000} {1}" -f @($index, $expected))
					Write-Debug ("Actual     #{0:0000} {1}" -f @($index, $actual))
					Write-Debug "@{$($Result.Keys | foreach { @($_, $Result[$_]) -join "=" })}"
				}

				if ($null -eq $expected.Result) {
					if ($null -ne $actual.Result -and $actual.Result -is [string] -and (Get-IsNotEmpty $actual.Result)) {
						$Result.Failure = $true
					}
				} elseif ($expected.Result -is [string]) {
					if (Get-IsEmpty $expected.Result) {
						if (Get-IsEmpty $actual.Result) {
							$Result.Failure = $true
						} else {
							$Result.AcResult = $null
						}
					} elseif ($expected.Result -ne $actual.Result) {
						$Result.Failure = $true
					}
				} elseif ($expected.Result -is [System.Array]) {
					if ($expected.Result.Length -ne $actual.Result.Length) {
						$Result.Failure = $true
					} else {
						for ($i = 0; $i -lt $expected.Result.Length; $i++) {
							if ($expected.Result[$i] -ne $actual.Result[$i]) {
								$Result.Failure = $true
								break;
							}
						}
					}
				} elseif ($expected.Result -is [bool]) {
					if ($expected.Result -ne $actual.Result) {
						$Result.Failure = $true
					}
				} else {
					$Result.Failure = $true
					Write-Error "Unexpected type '$($expected.Result.GetType())' of 'Result' in '$expected'."
				}
				if ($null -eq $expected.Name) {
					if ($null -ne $actual.Name) {
						$Result.Failure = $true
					}
				} elseif ($expected.Name -is [string]) {
					if ($expected.Name -ne $actual.Name) {
						$Result.Failure = $true
					}
				} else {
					Write-Error "Unexpected type '$($expected.Name.GetType())' of 'Result' in '$expected'."
					$Result.Failure = $true
				}
				if ($expected.IsItem -ne $actual.IsWalk) {
					$Result.Failure = $true
				}
				if ($expected.Errno -ne $actual.Errno) {
					$Result.Failure = $true
				}
				if ((Get-IsEmpty $expected.Error) -ne (Get-IsEmpty $actual.Error)) {
					$Result.Failure = $true
				}
				if ($expected.Errno -eq [ushort]($script:NotImplementedHResult -band 0xffff)) {
					$Result.Failure = $null
				}
				$pso = [pscustomobject]$Result
				if ($DebugPreference -ne $script:SilentlyContinue) {
					Write-Debug ("Joined     #{0:0000} {1}" -f @($index, $pso))
				}
				$pso
				if ($expectedIsDone -and $actualIsDone) {
					$index++
					break;
				}
			}
		} catch {
			DisposeFiles
			throw
		}
	}
}
<#
	.Synopsis
	Reads test data from a tab-separated file.

	.Description
	Reads a tab-separated file with test data.

	See api.go for the details about the supported API's and their arguments.

	See Get-Help -Full for details about the file format.

	.Parameter InFile
	The file system path of the input file.

	.Parameter RemainingArguments
	Captures named arguments used to replace named parameters in the input.

	See help for ConvertTo-Go for more information.

	.Inputs
	None.

	Reads the file specified in InFile.

	The file must have the following columns: Traits (optional), Api, Arg1, Arg2, Value1, Value2. The order and casing is not important.
	* Api should be in the format `package.Name` e.g. `os.Chdir` or `filepath.Abs`. Case-sensitive.
	* Arg1 and Arg2 are the names of the arguments, they are not validated but defined and interpreted by `api.go`. Case-sensitive.
	* Value1 and Value2 may be omitted if applicable, must be strings. Unless the corresponding argument name is Join, then it must be a ; separated list of strings.

	.Outputs
	Objects as defined by ConvertTo-Go.
#>
function Read-Go {
	[CmdLetBinding()]
	Param(
		[ValidateNotNull()]
		[string]$InFile,

		[Parameter(ValueFromRemainingArguments = $true)]$RemainingArguments
	)
	Begin {
		if ("FileSystem" -ne $PWD.Provider.Name) {
			throw [System.InvalidOperationException]::new("Cannot read or write files from PSProvider '$($PWD.Provider.Name)'. Use cd to switch to the filesystem.")
		}
		$index = 1
	}
	Process {
		$Splat = Splat -RemainingArguments $RemainingArguments

		Get-Content $InFile |
		ConvertFrom-Csv -Delimiter "`t" |
		Remove-GoNulls -EmptyStrings |
		ConvertTo-Go @Splat |
		foreach {
			$_ | Add-Member -MemberType NoteProperty -Name "Index" -Value ($index++) -TypeName System.Int32
			$_
		}
	}
}
<#
	.Synopsis
	Converts a single record from the format of the input test data to the format expected by the test programs.

	.Description
	Accepts pipeline input and produces pipeline output, converting the format of the tab-separated file to the format accepted by the test programs.

	.Parameter InputObject
	Accepts pipeline input. Each property that is present is expected to be a plain string.

	.Parameter RemainingArguments
	Accepts any named arguments required to replace parameters defined in the test data.

	Strings may contain named parameters enclosed in < and >, e.g. "\\?\Volume<volid>\Directory" (without quotes), which must be defined by providing them as arguments or environment variables. E.g. -volid "{9ae4cb50-7d96-40ce-a400-b02400b50722}".

	PowerShell may require quotes (for literal guids enclosed in { and }, specifically) - these will be dropped, unless they are escaped (-onequote "`"") or duplicated (-onequote '''').

	An attempt will be made to replace <name> for $env:GoTest<name> (without brackets).

	The following named arguments do not have to be specified:
	* <pwd> will be substituted for `Get-Location -PSProvider FileSystem` which equals `$PWD.Path` if the PowerShell working directory is anywhere on the file system.
	* <gcd> will be substituted for [System.IO.Directory]::GetCurrentDirectory() which may not equal `$PWD.Path` even if the $PWD.Provider is the FileSystem provider.
	* <null> will be substituted for "$null", unless the input string equals '<null>' in which case the string or object is set to $null.
	* Named arguments that cannot be replaced produce an error.

	The precedence and case-sensitivity is:
	1. Built in values pwd, gcd, null (case-sensitive)
	2. Arguments (case-insensitive)
	3. Environment variables (case-insensitive)

	.Inputs
	@{Traits, Api, Arg1, Arg2, Value1, Value2} as described in Read-Go.

	Empty strings in Value1 and Value2 are retained.

	These values and elements in Traits and Join may be the exact string '<null>' in which case they are substituted for $null.

	.Outputs
	@{Traits, Api, Path, Path2, Pattern, Join} as defined by `api.go` although no validation is done.

	* Traits may be a list of strings separated by comma (,). Whitespace will be trimmed from the start and end of each trait.
	* Join may be a list of strings separated by semi-colon (;). Whitespace will be kept.


#>
function ConvertTo-Go {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true)]$InputObject,
		[Parameter(ValueFromRemainingArguments = $true)]$RemainingArguments
	)
	Begin {
		$Parameters = Splat -RemainingArguments $RemainingArguments
	}
	Process {
		$index = $InputObject.Index
		if ($null -eq $index) {$index = 0}
		Write-GoObject -InputObject $InputObject -Format "#{1:0000} Input:  {0}" -FormatData @($index) -IfDebug

		$Result = [ordered]@{}
		$s = [string]$InputObject.Api
		if (Get-IsEmpty $s) {
			if (-not (Get-GoIsEmpty $InputObject)) {
				Write-Error "'$s' is invalid for 'Api'."
			}
			return [ordered]@{}
		}
		$Result.Api = $s

		if (Get-IsNotEmpty $InputObject.Arg1) {
			if ('<null>' -eq $InputObject.Value1) {
				$Result[$InputObject.Arg1] = $null
			} else {
				$Result[$InputObject.Arg1] = [string]$InputObject.Value1
			}
		}
		if (Get-IsNotEmpty $InputObject.Arg2) {
			if ('<null>' -eq $InputObject.Value2) {
				$Result[$InputObject.Arg2] = $null
			} else {
				$Result[$InputObject.Arg2] = [string]$InputObject.Value2
			}
		}
		# the remaining may just be remarks or clarifications
		if (Get-IsNotEmpty $InputObject.Arg3) {
			if ('<null>' -eq $InputObject.Value3) {
				$Result[$InputObject.Arg3] = $null
			} else {
				$Result[$InputObject.Arg3] = [string]$InputObject.Value3
			}
		}
		if (Get-IsNotEmpty $InputObject.Arg4) {
			if ('<null>' -eq $InputObject.Value4) {
				$Result[$InputObject.Arg4] = $null
			} else {
				$Result[$InputObject.Arg4] = [string]$InputObject.Value4
			}
		}

		function Substitute {
			[CmdLetBinding()]
			Param([Parameter(ValueFromPipeline = $true)][string]$v)
			Process {
				if (Get-IsEmpty $v) { return $v }

				$subst = $v
				$substituteUnicode = $false
				if ($substituteUnicode) {
					$rex = "<(?<n>[^>]+)>|\\u(?<u>[0-9a-fA-F]{4})"
				} else {
					$rex = "<(?<n>[^>]+)>"
				}
				while ($subst -match $rex) {
					$code = $Matches["u"]
					$name = $Matches["n"]
					if ($substituteUnicode -and $code.Length -gt 0) {
						$value = [char][int]::Parse($code, [System.Globalization.NumberStyles]::HexNumber)
					} elseif ($name.Length -gt 0) {
						if ($name -ceq "pwd") {
							$value = Get-Location -PSProvider FileSystem
						} elseif ($name -ceq "gcd") {
							$value = [System.IO.Directory]::GetCurrentDirectory()
						} elseif ($name -ceq 'null') {
							$value = $null
						} elseif ($Parameters.Contains($name)) {
							$value = $Parameters[$name]
						} else {
							$evar = dir "env:GoTest$name" -ErrorAction SilentlyContinue
							if ($null -ne $evar) {
								$value = $evar.Value
							} else {
								throw [System.ArgumentException]::new("'$v' requires a value for '$name'. " +
									"Add the 'GoTest$name' environment variable or the '$name' argument like so: -$name value or " +
									"`$splat = @{$name=value,othername=othervalue}; ConvertTo-Go @splat (...) " +
									"InputObject: $InputObject")
							}
						}
					} else {
						throw [System.ArgumentException]::new("'$v' is invalid.")
					}
					Write-Debug "'$($Matches[0])' will be replaced with '$value'."
					if ($Matches[0] -eq $subst) {
						$subst = $value
					} else {
						$subst = $subst.Replace($Matches[0], $value)
					}
				}
				return $subst
			}
		}

		@("Path", "Path2", "Pattern") | foreach {
			if (Get-IsEmpty $Result[$_]) { return }
			$Result[$_] = Substitute $Result[$_]
		}

		if ($InputObject.Traits -is [string]) {
			$Result.Traits = $InputObject.Traits.Split(",") | Substitute
			if ($Result.Traits -is [string]) {
				$array = [string[]]::new(1)
				$array[0] = $Result.Traits
				$Result.Traits = $array
			}
		}
		if ($Result.Join -is [string]) {
			$Result.Join = $Result.Join.Split(";") | Substitute
			if ($Result.Join -is [string]) {
				$array = [string[]]::new(1)
				$array[0] = $Result.Join
				$Result.Join = $array
			}
		}
		
		if ($DebugPreference -ne $script:SilentlyContinue) {
			$display = "@{$(($Result.Keys | foreach { "$_=$($Result[$_])" }) -join "; ")}"
			Write-Debug ("#{0:0000} Output: {1}" -f @(
				$index,
				$display))
		}
		[pscustomobject]$Result
		$index++
	}
}
<#
	.Synopsis
	Creates a single test using the specified arguments.
#>
function New-GoTest {
	[CmdLetBinding()]
	Param(
		[Parameter(ParameterSetName = "os")][switch]$os = [switch]::new($false),
		[Parameter(ParameterSetName = "filepath")][switch]$filepath = [switch]::new($false),
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]$Api,
		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 2)]$Traits,
		[Parameter(ValueFromRemainingArguments = $true)]$RemainingArguments
	)
	Process {
		$Result = [ordered]@{
			Traits = $Traits -join ","
			Api = @($PSCmdLet.ParameterSetName, $Api) -join "."
		}
		$Arguments = Splat $RemainingArguments
		$i = 0
		foreach ($k in $Arguments.Keys) { $i++; $Result.Add("Arg$i", [string]$k); Write-Debug "Arg$i $($k)=$($Arguments[$k])" }
		while ($i++ -lt 2) { $Result.Add("Arg$i", $null) }
		$i = 0
		foreach ($k in $Arguments.Keys) { $i++; $Result.Add("Value$i", $Arguments[$k]); Write-Debug "Value$i $($k)=$($Arguments[$k])" }
		while ($i++ -lt 2) { $Result.Add("Value$i", $null) }
		[pscustomobject]$Result
	}
}
<#
	.Synopsis
	Creates test objects for the API set specified, which have the right parameter names.

	.Parameter os
	Create one single test object for each of Chdir and Getwd.

	.Parameter filepath
	Create one single test object for each API supported aby 'api.go'.
#>
function Get-GoTests {
	[CmdLetBinding()]
	Param(
		[switch]$os = [switch]::new($false),
		[switch]$filepath = [switch]::new($false)
	)
	Process {
		if ($os.IsPresent) {
			New-GoTest -os -Api Chdir -Path $null
			New-GoTest -os -Api Getwd
		}
		if ($filepath.IsPresent) {
			New-GoTest -filepath -Api Separator
			New-GoTest -filepath -Api ListSeparator
			New-GoTest -filepath -Api Abs			-Path $null
			New-GoTest -filepath -Api EvalSymlinks	-Path $null
			New-GoTest -filepath -Api Glob			-Pattern $null
			New-GoTest -filepath -Api Match			-Pattern $null -Path $null
			New-GoTest -filepath -Api Rel			-Path $null -Path2 $null
			New-GoTest -filepath -Api Base			-Path $null
			New-GoTest -filepath -Api Clean			-Path $null
			New-GoTest -filepath -Api Dir			-Path $null
			New-GoTest -filepath -Api Ext			-Path $null
			New-GoTest -filepath -Api FromSlash		-Path $null
			New-GoTest -filepath -Api IsAbs			-Path $null
			New-GoTest -filepath -Api Join			-Join $null
			New-GoTest -filepath -Api SplitList		-Path $null
			New-GoTest -filepath -Api ToSlash		-Path $null
			New-GoTest -filepath -Api VolumeName	-Path $null
			New-GoTest -filepath -Api Split			-Path $null
			New-GoTest -filepath -Api Walk			-Path $null
		}
	}
}
<#
	.Synopsis
	Expands each input object to a series of tests.

	.Description
	Creates test series for each input object, the count depends on the number of arguments each input test takes and the number of elements provided in the values arguments.

	.Parameter Api
	The input test object, created with New-GoTest or Get-GoTests.

	.Parameter Values1
	A single value or an array of (usually) string values for the first argument of Api.

	If the API does not take any arguments, a single test is returned.

	.Parameter Values2
	A single value or an array of (usually) string values for the second argument of Api.

	If the API does not take more than one argument, this parameter is ignored.

	.Parameter Traits
	The traits that each object returned will receive.
#>
function Expand-GoTests {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true)]$Api,
		$Values1,
		$Values2,
		[string[]]$Traits
	)
	Begin {
		if ($null -eq $Traits -or $Traits -is [string]) {
			$JoinedTraits = $Traits
		} else {
			$JoinedTraits = [string]::Join(",", $Traits)
		}
	}
	Process {
		$test = [ordered]@{
			Traits = $JoinedTraits
			Api = $api.Api
			Arg1 = $api.Arg1
			Arg2 = $api.Arg2
			Value1 = $null
			Value2 = $null
			Remark = $null
		}
		Write-Verbose "Api: $Api"
		foreach ($v1 in $Values1) {
			Write-Verbose "Value1: $v1 for $Api"
			if (Get-IsEmpty $api.Arg1) {
				Write-Verbose "Arg1 is empty $test"
				[pscustomobject]$test; break
			}
			$test.Value1 = $v1
			if ($null -eq $Values2) {
				Write-Verbose "Value2 is null: $test"
				[pscustomobject]$test;
			}
			foreach ($v2 in $Values2) {
				Write-Verbose "Value2: $v2 for $Api"
				if ($api.Arg1 -eq "Join") {
					$test.Value1 = $v1 + ";" + $v2
					Write-Verbose $test
					[pscustomobject]$test
					continue
				}
				if (Get-IsEmpty $api.Arg2) {
					Write-Verbose "Arg2 is empty $test"
					[pscustomobject]$test; break
				}
				$test.Value2 = $v2
				Write-Verbose $test
				[pscustomobject]$test
			}
		}
	}
}
<#
	.Synopsis
	Converts any input data to the format expected by Read-Go and similar.

	.Description
	Replaces enumerables in each input object with strings in the output and converts the result to CSV with a Tab delimiter and without any quotes.
#>
function ConvertTo-GoCsv {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true)]$InputObject
	)
	Begin { $All = @() }
	Process { $All += $InputObject }
	End { $All | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never }
}
<#
	.Synopsis
	Builds standard test sets by enumerating tests for each of the switches provided.

	.Description
	The Nulls and EmptyStrings tests produce tests against all API's.

	The Smoke tests only tests against path/filepath API's.

	The PathMath and Invalid tests skip Walk and Glob.

	.Parameter Nulls
	Tests with $null strings - this is not very useful against go since go will always coerce null values to empty strings.

	.Parameter EmptyStrings
	Tests with empty strings.

	.Parameter Smoke
	Tests with a small number of parameters to quickly discover issues accross the API surface.

	.Parameter PathMath
	Tests with a larger number of parameters.

	.Parameter Invalid
	Tests with a larger number of parameters that include some invalid file name and invalid path characters.
#>
function Build-GoClassTests {
	[CmdLetBinding()]
	Param(
		[Parameter(ParameterSetName = "TestSets")][switch]$Nulls = [switch]::new($false),
		[Parameter(ParameterSetName = "TestSets")][switch]$EmptyStrings = [switch]::new($false),
		[Parameter(ParameterSetName = "TestSets")][switch]$Smoke = [switch]::new($false),
		[Parameter(ParameterSetName = "TestSets")][switch]$PathMath = [switch]::new($false),
		[Parameter(ParameterSetName = "TestSets")][switch]$invalid = [switch]::new($false),

		[string]$WorkingDirectory = $null
	)
	Begin {
		$readable = $script:InvalidChars | foreach {
			if ([char]::IsControl($_)) {
				"\u{0:x4}" -f @([int]$_)
			} else {
				$_
			}
		}
	}
	Process {
		if (Get-IsNotEmpty $WorkingDirectory) {
			New-GoTest -os -Api Chdir -Path $WorkingDirectory -Traits "Setup"
		}
		if ($Nulls.IsPresent) {
			Get-GoTests -os -filepath | Expand-GoTests -Values1 '<null>' -Values2 '<null>' -Traits "Null"
		}
		if ($EmptyStrings.IsPresent) {
			Get-GoTests -os -filepath | Expand-GoTests -Values1 "" -Values2 "" -Traits "Empty"
		}
		if ($Smoke.IsPresent) {
			$values = @('.', '\\?\..', '\\?\<peculiar>\OneFile', 'Q:\NonExisting', '\\?\Q:\NonExisting', '//?/', "\\?\Volume{$([guid]::new([byte[]]::new(16)))}")
			Get-GoTests -filepath | Expand-GoTests -Values1 $values -Values2 $values -Traits "Smoke"
		}
		function Make([bool]$Invalid) {
			$apis = Get-GoTests -filepath |
				where Api -notmatch Walk |
				where Api -notmatch Glob |
				where { Get-IsEmpty $_.Arg2 }
			if ($Invalid) {
				$prefixy = @("", "\\", "\\?\", "\\?\UNC\")
			} else {
				$prefixy = @("",
					"\\",
					#"\/", "/\",
					"//",
					"\??\",
					#"\??/", "/??\",
					#"/??/",
					"\\?\",
					#"\\?/", "/\?\", "/\?/", "\/?\", "\/?/", "//?\",
					"//?/",
					"\\.\"
					#"\\./", "/\.\", "/\./", "\/.\", "\/./", "//.\",
					#"//./"
					"\\?\UNC\"
				)
			}
			if ($Invalid) {
				$path = @("", "C:", "server\share")
			} else {
				$pathy = @(
					"",
					"c:",
					"volumE<volid>",
					"unC",
					"127.0.0.1",
					"server\share")
			}
			if ($Invalid) {
				$suffixy = @("", "\:\", "\*\", "\`"\")
			} else {
				$suffixy = @(
					"", ".", "..", "*",
					"\/",
					# "\\", "//",
					"/", "/.",
					#"/..",
					#"\", "\.",
					"\..",
					"/sharverdir/..", "\/sharver/shardir", "/sharver/shardir/..")
			}
			$values =
				$prefixy | foreach { $pre = $_;
				$pathy   | foreach { $pad = $_;
				$suffixy | foreach { $suf = $_;
				"$pre$pad$suf"
			}}}
			$join =
				$prefixy | foreach { $pre = $_;
				$pathy   | foreach { $pad = $_;
				$suffixy | foreach { $suf = $_;
				"$pre$pad;$suf"
			}}}
			$apis | Expand-GoTests -Values1 $values
			New-GoTest -filepath -Api Join -Join $null | Expand-GoTests -Values1 $join -Values2 $suffixy
			New-GoTest -filepath -Api Match -Pattern $null -Path $null | Expand-GoTests -Values1 $suffixy -Values2 $values
			New-GoTest -filepath -Api Rel -Path $null -Path2 $null | Expand-GoTests -Values1 $values -Values2 $suffixy
		}
		if ($PathMath.IsPresent) { Make($false) }
		if ($Invalid.IsPresent) { Make($true) }
	}
}
<#
	.Synopsis
	Patches `dir` (Get-ChildItem) to work with weird filenames and traverses links, but introduces issues when the filesystem contains loops.

	.Parameter Path
	The path to enumerate.

	.Parameter FileSystem
	Initializes the Path parameter to $env:GoTestRoot.

	.Parameter FileServer
	Initializes the Path parameter to $env:GoTestLocal\.
#>
function Get-GoChildItem {
	[CmdLetBinding()]
	Param(
		[Parameter(ParameterSetName = "Path")][string]$Path,
		[Parameter(ParameterSetName = "FileSystem")][switch]$FileSystem = [switch]::new($false),
		[Parameter(ParameterSetName = "FileServer")][switch]$FileServer = [switch]::new($false),

		[Parameter(ParameterSetName = "Path")]
		[Parameter(ParameterSetName = "FileSystem")]
		[Parameter(ParameterSetName = "FileServer")][switch]$Recurse = [switch]::new($false)
	)
	Begin {
		if ($FileSystem.IsPresent) { $Path = $env:GoTestRoot }
		elseif ($FileServer.IsPresent) { $Path = $env:GoTestLocal }

		if (-not $Path.EndsWith("\") -and -not [System.IO.File]::Exists($path)) {
			$Path += "\"
		}
		if ([System.IO.Directory]::Exists($Path)) {
			Write-Verbose "Yielding $Path"
			[System.IO.DirectoryInfo]::new($Path)
		} else {
			throw [System.IO.DirectoryNotFoundException]::new()
		}
	}
	Process {
		function PrivateEnumerate([string]$Path, [switch]$Recurse) {
			Write-Verbose "Enumerating $path"
			try {
				$children = [System.IO.Directory]::EnumerateFileSystemEntries($Path, "*.*", [System.IO.SearchOption]::TopDirectoryOnly)
			} catch {
				Write-Verbose "Failed to enumerate '$Path': $_."
				return
			}
			foreach ($child in $children) {
				try {
					if ($child.StartsWith("\\?\")) {
						$np = $child
					} elseif ($child.StartsWith("\\")) {
						$np = "\\?\UNC\" + $child.Substring(2)
					} else {
						$np = "\\?\" + $child
					}
					Write-Verbose "Child: '$child'"
					if ([System.IO.File]::Exists($np)) { 
						if ([System.IO.File]::Exists($child)) { Write-Verbose "File '$child'"
							$fsi = [System.IO.FileInfo]::new($child)
						} else { Write-Verbose "File '$np'"
							$fsi = [System.IO.FileInfo]::new($np)
						}
					} else {
						if ([System.IO.Directory]::Exists($child)) { Write-Verbose "Dir '$child'"
							$fsi = [System.IO.DirectoryInfo]::new($child)
						} else { Write-Verbose "Dir '$np'"
							$fsi = [System.IO.DirectoryInfo]::new($np)
						}
					}
				} catch {
					Write-Warning $Error[0]
					continue
				}
				$fsi
				if ($Recurse.IsPresent -and $fsi -is [System.IO.DirectoryInfo] -and $null -eq $fsi.LinkType) {
					foreach ($recursive in (PrivateEnumerate $fsi.FullName -Recurse:$Recurse)) { $recursive }
				}
			}
		}
		PrivateEnumerate $Path -Recurse:$Recurse
	}
}
<#
	.Synopsis
	Builds tests for EvalSymlinks against paths found in the environment variables with the specified prefixes and suffixes.
#>
function Build-GoEvalSymlinksTests {
	[CmdLetBinding()]
	Param(
		[switch]$AgainstPeculiar = [switch]::new($false),
		[switch]$AgainstLocal = [switch]::new($false),
		[switch]$AgainstRemote = [switch]::new($false),
		[switch]$AgainstVhdLink = [switch]::new($false),
		[switch]$AgainstVhdRoot = [switch]::new($false),
		[switch]$SuffixNone = [switch]::new($false),
		[switch]$SuffixDrive = [switch]::new($false),
		[switch]$SuffixGuid = [switch]::new($false),
		[switch]$SuffixHardLink = [switch]::new($false),
		[switch]$SuffixIdentity = [switch]::new($false),
		[switch]$SuffixJunction = [switch]::new($false),
		[switch]$SuffixSmb = [switch]::new($false),
		[switch]$SuffixSmbNoParse = [switch]::new($false),
		[string[]]$AdditionalSuffixes
	)
	Process {
		if (Get-IsEmpty $env:GoTestName) {
			Write-Error "The test environment may not have been setup. Run Mount-Go."
		}
		$variables = [System.Collections.Generic.List[string]]::new()
		if ($AgainstPeculiar.IsPresent	) { dir env:GoTestPeculiar* | sort Name | foreach { $variables.Add($_.Name) } }
		if ($AgainstLocal.IsPresent		) { dir env:GoTestLocal* | sort Name | foreach { $variables.Add($_.Name) } }
		if ($AgainstRemote.IsPresent	) { dir env:GoTestRemote* | sort Name | foreach { $variables.Add($_.Name) } }
		if ($AgainstVhdLink.IsPresent	) { dir env:GoTestVhdLink* | sort Name | foreach { $variables.Add($_.Name) } }
		if ($AgainstVhdRoot.IsPresent	) { dir env:GoTestVhdRoot* | sort Name | foreach { $variables.Add($_.Name) } }
		Write-Verbose "Selected: $($variables -join ";")"
		$variables = $variables | where { Get-IsNotEmpty (dir "env:$_" -ErrorAction SilentlyContinue) }
		Write-Verbose "Present: $($variables -join ";")"
		$prefixes = @("Local", "Remote", "VhdRoot", "VolId", "Peculiar")
		foreach ($variable in $variables) {
			$root = [string](dir "env:$variable").Value
			$varname = $variable.Substring("GoTest".Length)
			$prefix = "Default" # "" is a poor trait
			foreach ($p in $prefixes) {
				if ($varname.StartsWith($p)) {
					$prefix = $p
					$suffix = $varname.Substring($p.Length)
					break;
				}
			}
			if ($suffix -eq "") { $suffix = "None" } # "" is a poor trait
			Write-Verbose "Variable=$variable GoTest=$varname Prefix=$prefix Suffix=$suffix Root=$root"
			$skip = $false;
			switch ($suffix) {
				"None"			{ if (-not $SuffixNone.IsPresent) { $skip = $true } }
				"Drive"			{ if (-not $SuffixDrive.IsPresent) { $skip = $true } }
				"Guid"			{ if (-not $SuffixGuid.IsPresent) { $skip = $true } }
				"HardLink"		{ if (-not $SuffixHardLink.IsPresent) { $skip = $true } }
				"Identity"		{ if (-not $SuffixIdentity.IsPresent) { $skip = $true } }
				"Junction"		{ if (-not $SuffixJunction.IsPresent) { $skip = $true } }
				"Smb"			{ if (-not $SuffixSmb.IsPresent) { $skip = $true } }
				"SmbNoParse"	{ if (-not $SuffixSmbNoParse.IsPresent) { $skip = $true } }
				default {
					if ($null -eq $AdditionalSuffixes -or $AdditionalSuffixes -notcontains $suffix) { $skip = $true }
				}
			}
			Write-Verbose "Variable=$variable GoTest=$varname Prefix=$prefix Suffix=$suffix Root=$root Skip=$skip"
			if ($skip) { continue }
			$index = 0
			foreach ($fsi in (Get-GoChildItem -Path $root -Recurse)) {
				$name = $fsi.Name
				$full = $fsi.FullName
				if ($index -ne 0 -and $null -eq $fsi.LinkType -and -not $fsi.Name.Contains("Link") -or $fsi.Extension -match "vhdx") {
					Write-Debug "Skipping '$fsi' because it is not a link."
					continue
				} else {
					$index++
				}
				if (!$full.EndsWith("\") -and 0 -ne ($fsi.Attributes -band [System.IO.FileAttributes]::Directory)) {
					$full += "\"
				}
				$result = New-GoTest -filepath -Api EvalSymlinks -Path $full -LinkType $fsi.LinkType -Target $fsi.Target -Traits Links, $prefix, $suffix
				Write-Verbose $result
				$result
			}
		}
	}
}
<#
	.Synopsis
	Creates a list of tests for EvalSymlinks, writes them to a .csv, tests them and then creates a HTML reports with a selection of columns.
#>
function Build-GoEvalSymlinksReport {
	[CmdLetBinding()]
	Param(
		[string]$OutFile
	)
	Process {
		$list = Build-GoEvalSymlinksTests -AgainstLocal -AgainstPeculiar -SuffixNone
		$list += Build-GoEvalSymlinksTests -AgainstVhdRoot -SuffixDrive
		$list += Build-GoEvalSymlinksTests -AgainstRemote -AdditionalSuffixes FileServer
		$list | ConvertTo-GoCsv | Out-File $OutFile
		Test-Go -InFile .\links.csv -GenerateExpected
		$InFile = [System.IO.Path]::ChangeExtension($OutFile, ".results.json")
		ConvertTo-GoBriefHtml -InFile $InFile
	}
}
<#
	.Synopsis
	Converts extended test result object such as produced by Test-Go into a 6-column HTML table.

	.Description
	Purpose built to support Build-GoEvalSymlinksReport.
#>
function ConvertTo-GoBriefHtml {
	[CmdLetBinding()]
	Param([string]$InFile)
	Process {
		$Split = [System.IO.Path]::GetFileName($InFile)
		$Split = $Split.Split([char]'.')
		$OK = $false
		$Expected = ".results.json"
		for ($i = 0; $i -lt $Split.Length; $i++) {
			$ext = "." + (($Split | select -Skip $i) -join ".")
			if ($Expected.Equals($ext, [System.StringComparison]::OrdinalIgnoreCase)) {
				$OK = $true
				break
			}
		}
		if (!$OK) {
			Write-Warning "Converting '$InFile' may not produce the expected result. This CmdLet expects '<basename>$Expected' as input, e.g. '$($Split[0])$Expected'."
		}
		$OutFile = [System.IO.Path]::ChangeExtension($InFile, ".brief.html")
		Get-Content $InFile |
			ConvertFrom-Json |
			foreach {
				$_.Traits = $_.Traits -join ","
				$_.Path = $_.Path -replace "[_]{20,2000}", "___(...Path Segment Length MAX_PATH-5...)___"
				$_.AcError = $_.AcError -replace "[_]{20,2000}", "___(...Path Segment Length MAX_PATH-5...)___"
				$_.Target = $_.Target -replace "[_]{20,2000}", "___(...Path Segment Length MAX_PATH-5...)___"
				$LinkType = $_.LinkType
				if ($_.Path.Contains("FileHardLink")) {
					$LinkType = "HardLink (File)"
				}
				[pscustomobject][ordered]@{
					Errno=$_.AcErrno
					Path=$_.Path
					Result=$_.AcResult
					LinkType=$LinkType
					Target=$_.Target
					Error=$_.AcError
				}
			} | ConvertTo-Html -Fragment | Out-File $OutFile
		dir $OutFile
	}
}
function Write-GoObject {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true)]$InputObject,
		[string]$Format,
		[object[]]$FormatData,
		[switch]$IfDebug = [switch]::new($false),
		[switch]$IfVerbose = [switch]::new($false)
	)
	Process {
		function Get-Value($InputObject) {
			if ($null -eq $InputObject) {
				"`$null"
			} elseif ($InputObject -is [string] -or $InputObject.GetType().IsValueType) {
				$value.ToString()
			} elseif ($InputObject -is [System.Collections.IEnumerable]) {
				($value | Get-Value) -join ", "
			} elseif ($InputObject -is [hashtable]) {
				$value = $InputObject.Keys | foreach { "$_=$(Get-Value $InputObject."$_")" }
				"@{ $($value -join ", ") }"
			} elseif ($InputObject -is [System.Collections.Specialized.OrderedDictionary]) {
				$value = $InputObject.Keys | foreach { "$_=$(Get-Value $InputObject."$_")" }
				"@{ $($value -join ", ") }"
			} else {
				$value.ToString()
			}
		}
		function Format([object[]]$Arguments) {
			#for ($i = 0; $i -lt $Arguments.Length; $i++) { Write-Debug ("{0:00}: {1} ({2})" -f @($i, $Arguments[$i], $Arguments[$i].GetType())) }
			if ($null -eq $Format) {
				Get-Value $Arguments[0]
			} else {
				[string]::Format($Format, $Arguments)
			}
		}
		$list = [System.Collections.Generic.List[object]]::new()
		$list.Add($InputObject)
		foreach ($fd in $FormatData) { $list.Add($fd) }

		if ($IfVerbose.IsPresent -and $VerbosePreference -ne $script:SilentlyContinue) {
			Write-Verbose (Format $list)
		} elseif ($IfDebug.IsPresent -and $DebugPreference -ne $script:SilentlyContinue) {
			Write-Debug (Format $list)
		}
	}
}
<#
	.Synopsis
	Converts string arguments to a hashtable that can be used as splatted arguments. See about_Splatting.

	.Description
	Converts string arguments to a hashtable that can be used as splatted arguments. See about_Splatting.

	.Parameter RemainingArguments
	Any arguments at all; both switches and name-value pairs.
#>
function Splat {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromRemainingArguments = $true)]$RemainingArguments
	)
	Process {
		if ($RemainingArguments -is [hashtable]) {
			return $RemainingArguments
		}
		function convert($vars) {
			$hashtable = [ordered]@{}
			if ($null -eq $vars) { return $hashtable }
			if ($vars -is [System.Collections.Generic.List[object]] -and $vars.Count -le 1 -and $null -eq $vars[0]) { return $hashtable }
			$index = 0
			foreach ($var in $vars) {
				if ($null -eq $var) {
					Write-Debug "#$index is `$null (Switch '$SwitchName')"
				} else {
					Write-Debug "#$index = $var ($($var.GetType())) (Switch '$SwitchName')"
				}
				$index++

				if ($var -match "^-(?<n>.*):(?<v>.+)$") {
					$n = $Matches["n"]
					$v = $Matches["v"]
					Write-Debug "-$($n):$v"
					$hashtable.Add($n, $v)
					$SwitchName = $null
				} elseif ($var -match "^-(?<n>.*)[:]?$") {
					$n = $Matches["n"]
					Write-Debug "-$($n):`$true"
					$hashtable.Add($n, $true)
					$SwitchName = $n
				} elseif ($null -ne $SwitchName) {
					$n = $SwitchName
					Write-Debug "-$($n) $var"
					$hashtable[$n] = $var
					$SwitchName = $null
				} else {
					Write-Debug "$var => `$null"
					$hashtable.Add($var, $null)
				}
			}
			if ($null -ne $SwitchName) {
				$n = $SwitchName
				Write-Debug "-$($n) `$true"
				$hashtable.Add($n, $true)
			}
			return $hashtable
		}
		if ($null -eq $RemainingArguments) {
			Write-Debug "RemainingArguments: `$null"
		} else {
			Write-Debug "RemainingArguments: $($RemainingArguments.GetType()) $RemainingArguments Count: $($RemainingArguments.Count)"
		}
		$Str = $RemainingArguments -join ", "
		$Splat = convert($RemainingArguments)
		$Str = ($Splat.Keys | foreach { "$_=$($Splat[$_])" }) -join ", "
		if ($VerbosePreference -ne $script:SilentlyContinue) {
			Write-Debug "Splat: $Str"
		}
		$Splat
	}
}
<#
	.Synopsis
	Verifies that there are no properties that are not null, 0 or false in a hashtable or pscustomobject.

	.Description
	Verifies that there are no properties that are not null, 0 or false in a hashtable or pscustomobject.

	.Parameter InputObject
	Pipeline input.

	.Inputs
	A stream or value of either [hashtable] or [pscustomobject].

	.Outputs
	$true if there are no properties with values other than the default for their type. $false otherwise.
#>
function Get-GoIsEmpty {
	Param([Parameter(ValueFromPipeline = $true)]$InputObject)
	Process {
		if ($null -eq $InputObject) {
			return $true
		}
		if ($InputObject -is [hashtable]) {
			foreach ($key in $InputObject.Keys) {
				if (-not (Get-GoIsDefault $InputObject[$key])) { return $false }
			}
		} elseif ($InputObject -is [pscustomobject]) {
			foreach ($name in ($InputObject | Get-Member -Type NoteProperty).Name) {
				if (-not (Get-GoIsDefault $InputObject."$name")) { return $false }
			}
		}
		return $true
	}
}
<#
	.Synopsis
	Determines whether the value is the default for its type.

	.Description
	Determines whether the value is the default for its type.

	.Parameter InputObject
	Pipeline input.

	.Parameter EmptyStrings
	If the value is "" and this switch is specified, the result will be $true.

	.Parameter EmptyArrays
	If the value is an array and the length is 0, the result will be $true.

	.Inputs
	A stream of objects.

	.Outputs
	$true if the input is the default for their type. $false otherwise.
#>
function Get-GoIsDefault {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true)]$InputObject,
		[switch]$EmptyStrings = [switch]::new($false),
		[switch]$EmptyArrays = [switch]::new($false)
	)
	Process {
		if ([System.Object]::ReferenceEquals($null, $InputObject)) {
#			Write-Debug "$InputObject is `$null"
			return $true
		}
		$type = $InputObject.GetType()
		if ($EmptyStrings.IsPresent -and ($InputObject -is [string]) -and ("" -eq $InputObject)) {
#			Write-Debug "$InputObject is an empty string"
			return $true
		}
		if ($EmptyArrays.IsPresent -and ($InputObject -is [System.Array]) -and ($InputObject.Length -eq 0)) {
#			Write-Debug "$InputObject is an empty array"
			return $true
		}
		if (-not $type.IsValueType) {
			$result = $null -eq $InputObject
#			Write-Debug "$InputObject equals `$null: $result"
			return $result
		}
		$default = [System.Activator]::CreateInstance($type)
		$result = [System.Object]::Equals($default, $InputObject)
#		Write-Debug "$InputObject equals default($type): $result"
		return $result
	}
}
<#
	.Synopsis
	Remove properties that are null, 0 or false from a hashtable or pscustomobject.

	.Description
	Remove properties that are null, 0 or false from a hashtable or pscustomobject.

	.Parameter InputObject
	Pipeline input.

	.Inputs
	A stream or value of either [hashtable] or [pscustomobject].

	.Outputs
	The input is returned after removing keys whose value is null or properties that are null.
#>
function Remove-GoNulls {
	[CmdLetBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true)]$InputObject,
		[switch]$EmptyStrings = [switch]::new($false),
		[switch]$EmptyArrays = [switch]::new($false)
	)
	Begin {
		$Splat = [ordered]@{
			EmptyStrings = $EmptyStrings 
			EmptyArrays  = $EmptyArrays  
		}
	}
	Process {
		if ($null -eq $InputObject) {
			return $null
		} elseif (($InputObject -is [hashtable]) -or ($InputObject -is [System.Collections.Specialized.OrderedDictionary])) {
			$keys = [System.Collections.Generic.List[object]]::new()
			foreach ($key in $InputObject.Keys) { $keys.Add($key) }
			foreach ($key in $keys) {
				$value = $InputObject[$key]
				$default = Get-GoIsDefault -InputObject $value @Splat
#				Write-Debug "Evaluating $key=$value (Default: $default)"
				if ($default) { $InputObject.Remove($key) }
			}
		} elseif ($InputObject -is [pscustomobject]) {
			foreach ($name in ($InputObject | Get-Member -Type NoteProperty).Name) {
				$value = $InputObject."$name"
				$default = Get-GoIsDefault -InputObject $value @Splat
#				Write-Debug "Evaluating $name=$value (Default: $default)"
				if ($default) { $InputObject.PSObject.Properties.Remove($name) }
			}
		} else {
			Write-Warning "Remove-GoNulls: Cannot handle type '$($InputObject.GetType())' of value '$InputObject'. Passing through unmodified."
		}
		$InputObject
	}
}
<#
	.Synopsis
	Don't display "System.Object[]" in HTML; use &l/rsaquo; to bypass HTML escaping.

	.Description
	Joins enumerables in the input using the string , or ‹br/›

	.Inputs
	Any object.

	.Outputs
	The input object with its Traits joined using ',' and its Join, ExResult, AcResult joined using ‹br/›.
#>
function Undo-GoEnumerables {
	[CmdLetBinding()]
	Param([Parameter(ValueFromPipeline = $true)]$InputObject)
	Process {
		if ($InputObject.Traits -is [string]) {
		} elseif ($InputObject.Traits -is [System.Collections.IEnumerable]) {
			$InputObject.Traits = $InputObject.Traits -join ","
		}
		if ($InputObject.Join -is [string]) {
		} elseif ($InputObject.Join -is [System.Collections.IEnumerable]) {
			$InputObject.Join = $InputObject.Join -join "‹br/›"
		}
		if ($InputObject.ExResult -is [string]) {
		} elseif ($InputObject.ExResult -is [System.Collections.IEnumerable]) {
			$InputObject.ExResult = $InputObject.ExResult -join "‹br/›"
		}
		if ($InputObject.AcResult -is [string]) {
		} elseif ($InputObject.AcResult -is [System.Collections.IEnumerable]) {
			$InputObject.AcResult = $InputObject.AcResult -join "‹br/›"
		}
		$InputObject
	}
}
<#
	.Synopsis
	Replace &lsaquo; '‹' for '<' and &rsaquo; '›' for '>'.

	.Description
	Undoes the HTML escaping performed by Undo-GoEnumerables.

	.Inputs
	Any string.

	.Outputs
	All occurrences of &lsaquo; '‹' and &rsaquo; '›' in the string are replaced.
#>
function Redo-GoHtml {
	[CmdLetBinding()]
	Param([Parameter(ValueFromPipeline = $true)]$InputObject)
	Process { $InputObject.Replace([char]"‹", [char]"<").Replace([char]"›", [char]">") }
}
<#
	.Synopsis
	Returns whether the given string is $null or "".
#>
function Get-IsEmpty([string]$value) {[string]::IsNullOrEmpty($value)}
<#
	.Synopsis
	Returns whether the given string is neither $null nor "".
#>
function Get-IsNotEmpty([string]$value) {-not [string]::IsNullOrEmpty($value)}
