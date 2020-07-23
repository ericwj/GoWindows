



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
