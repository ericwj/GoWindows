# Authoring Tests

## Test Definition File Format

The format of *Test Definition Files* is Tab Separated Values (`.csv`) without quotes.

> These files open beautifully in *Microsoft Excel*, if deemed handy.

```PowerShell
PS> Get-Content .\pathmath.csv | ConvertFrom-Csv -Delimiter "`t" | select -First 5

Traits  Api     Arg1    Arg2    Value1  Value2  Remark
-----------------------------------------
filepath.Join   Join
filepath.Join   Join            .
filepath.Join   Join            ..
filepath.Join   Join            *
filepath.Join   Join            \/
```
These are real objects:
```PowerShell
PS> Get-Content .\pathmath.csv | ConvertFrom-Csv -Delimiter "`t" | select -First 5 | where Value1 -eq "*"

Traits :
Api    : filepath.Join
Arg1   : Join
Arg2   :
Value1 : *
Value2 :
Remark :
```

## Columns
All columns present in the file will be read, whatever they are named or in what order they appear.
However, they may be lost if the file is then read and converted by `Test-Go` for example and
stored as JSON afterwards.

> The file above has the `Remarks` column which is only included for potential manual 
> comments written by humans. The value is not used anywhere.

As shown, the file has the following columns that will be used or remembered:

|Name|Description|
|:--           |:--|
|`Api`           |`api.go` defines the names of API's that are recognized.<br/>They are in the format `os.ApiName` or `filepath.ApiName`.
|`Arg1..Arg4`    |`api.go` defines the names of arguments that each API recognizes.<br/>It is safest to assume these names are case-sensitive.<br/>The arguments *Target* and *LinkType* are recognized by `ConvertTo-GoBriefHtml` and `Join-go` exclusively, to make them appear in HTML reports for `EvalSymlinks`, case-insensitive.<br/>The number of arguments supported is currently 4, with usually 1 or 2 used by the go API and the remaining free for misuse as described.
|`Value1..Value4`|The value of the argument with the name specified in the corresponding `ArgN` column.
|`Traits`        |Traits are optional strings which allow filtering tests or reporting statistics.<br/>In the test definition file, the column should contain short strings separated by commas (`,`).<br/>`epi.exe` remembers this property and carries it from input to output JSON.
|`Index` (implicit)|The line-by-line ordering of tests in this file will show up as `Index` property in JSON input files.<br/>If this property is present in the *Test Definition File*, its value may be overwritten.<br/>`epi.exe` remembers this property and carries it from input to expected test result output JSON.<br/>It is not used at this time to match test input with test results.

## Values

Values are usually strings.
`api.go` defines the expected type for arguments that it recognizes and uses.

The `Join` argument is a `string[]` array, the delimiter is semicolon (`;`).

Values may contain names anywhere and as many times as needed, escaped like `<name>`,
which are substituted if recognized.

Substitution occurs before any tests are run, in the PowerShell CmdLet `ConvertTo-Go`,
which is used by `Read-Go` which in turn is used by `Test-Go`.

The precedence is:
1. Special Names
1. Ad-Hoc Arguments
1. Environment Variables

Specifying unrecognized names is an error.

> It is safest to assume that these names are matched *case-sensitively*.

#### Substitutions for Special Names
The following special names may be used:

* `<null>` will be substituted for `$null`.
* `<pwd>` is the PowerShell working directory and will be substituted for `$PWD`.
* `<gcd>` is the Windows working directory and will be substituted for `GetCurrentDirectory()`.

The result will only be `$null` when the specified value is exactly `<null>`.
`<null>` values part of larger strings simply disappear.
Specifying `null` is useful to keep e.g. VS Code from stripping significant whitespace,
such as filenames that are single spaces.
It is also useful to test C# API implementations, since C# `string`s can be null
while go `string`s cannot.
`Build-GoClassTests` has switch `-Null` which produces a list of tests with just `<null>` values.


> Note that the operating systems *current directory* concept is usually quite different 
> from `$PWD` - normal users who never change it might be all over the place inside PowerShell 
> for hours with the Windows current directory untouched at `$env:Windir\system32`. 
> This is fine unless .NET API's such as `[System.IO.File]::WriteAllText` are used from PowerShell.
> .NET API's have no knowledge of `$PWD`. Next to that, PowerShell is less reliable working 
> with uncommon path formats and is completely unable to work with valid paths that contain 
> leading or trailing spaces, for example.

#### Substitutions from Ad-Hoc Arguments

`Test-Go` accepts a typeless `-RemainingArguments` parameter, which is very unhelpful to
figure out if encountered without having read this - but it follows a powerful PowerShell paradigm.

`Test-Go` can be provided with arguments with *any name* and *any value*, including none,
in which case the value will be 'Present' or `$true`.

The names of these arguments may be substituted.
The values are not checked to be `[string]`, but specifying anything else
will be coerced to `[string]` implicitly.

`New-GoTest` uses `-RemainingArguments` too; it does **not** have a `Path` argument,
both their uses are demonstrated here:

```PowerShell
PS> New-GoTest -filepath -Api Abs -Path "<null>\\?\<gcd><weird>" | ConvertTo-GoCsv | Out-File .\demo.csv
PS> Test-Go .\demo.csv -Weird ";*" -Debug
DEBUG: #0000 Input:  @{Api=filepath.Abs; Arg1=Path; Value1=<null>\\?\<gcd><weird>}
DEBUG: '<null>' will be replaced with ''.
DEBUG: '<gcd>' will be replaced with '\\?\unc\localhost\Test'.
DEBUG: '<weird>' will be replaced with ';*'.
DEBUG: #0000 Output: @{Api=filepath.Abs; Path=\\?\\\?\unc\localhost\Test;*}
PS> Get-Content .\demo.results.json | ConvertFrom-Json

Failure  : True
Api      : filepath.Abs
ExResult : \\?\\\?\unc\localhost\Test;*
AcResult : \\?\?\unc\localhost\Test;*
Path     : \\?\\\?\unc\localhost\Test;*
Index    : 1
```

#### Substitutions from Environment Variables

`<name>` will be substituted for the environment variable called `GoTest<name>`
if that variable is defined.

`Mount-Go` produces a long list of these - and more can easily be added if required.
`Mount-Go` also lists these after it is done mounting virtual disks and the other work it does.
The command lists all of them, including those that were already defined before `Mount-Go` was invoked.

```PowerShell
PS> Mount-Go
(...)
dir env:GoTest<name> - Environment variables - <name> can be used for argument substitution

Name                           Value
----                           -----
GoTestLocal                    B:
GoTestLocalSmb                 D:
GoTestLocalSmbNoParse          F:
GoTestLong1                    1. GoFilePath Directory ______________________________________________________________________________________________________________________________…
GoTestLong2                    2. GoFilePath Directory ______________________________________________________________________________________________________________________________…
GoTestLong3                    3. GoFilePath Directory ______________________________________________________________________________________________________________________________…
GoTestLong4                    4. GoFilePath File ___________________________________________________________________________________________________________________________________…
GoTestName                     GoFilePath
GoTestNoDos                    C:\go\Peculiar\DosWasHere
GoTestNoNet                    \\GONE31915684\ConnectivityLost
GoTestNoVol                    \\?\Volume{00000000-0000-0000-0000-000000000000}
GoTestPeculiar                 C:\go\Peculiar
GoTestPeculiarDrive            G:\Peculiar
GoTestPeculiarFileServer       \\WS19\GoFilePath\Peculiar
GoTestPeculiarGuid             \\?\Volume{ae9e40ec-73a3-446c-8e57-2fdb70a9a849}\Peculiar
GoTestPeculiarHardLink         C:\go\Peculiar\HardLink\Peculiar
GoTestPeculiarIdentity         C:\go\Peculiar\Identity\Peculiar
GoTestPeculiarJunction         C:\go\Peculiar\Junction\Peculiar
GoTestRemote                   \\localhost\GoFilePath
GoTestRemoteFileServer         \\WS19\GoFilePath
GoTestRemoteSmb                \\localhost\GoFilePathSmb
GoTestRemoteSmbNoParse         \\localhost\GoFilePathSmbNoParse
GoTestRoot                     C:\go
GoTestShared                   C:\go
GoTestSharedSmb                C:\go\Peculiar\SmbShare
GoTestSharedSmbNoParse         \\?\C:\go\Peculiar\SmbShare
GoTestSuffixes                 Guid;Drive;Identity;Junction;HardLink
GoTestVhdLinkHardLink          C:\go\Peculiar\HardLink
GoTestVhdLinkIdentity          C:\go\Peculiar\Identity
GoTestVhdLinkJunction          C:\go\Peculiar\Junction
GoTestVhdRootDrive             G:
GoTestVhdRootGuid              \\?\Volume{ae9e40ec-73a3-446c-8e57-2fdb70a9a849}
GoTestVhdRootHardLink          \\?\Volume{587c9714-e22e-423a-9421-294a2c043d22}
GoTestVhdRootIdentity          C:\go\Peculiar\Identity
GoTestVhdRootJunction          \\?\Volume{7bbce513-361b-4ff4-aedb-09499749192a}
GoTestVolId                    {00000000-0000-0000-0000-000000000000}
GoTestVolIdDrive               {25466b02-6a2d-4243-b164-67e2d7d35c27}
GoTestVolIdGuid                {ae9e40ec-73a3-446c-8e57-2fdb70a9a849}
GoTestVolIdHardLink            {587c9714-e22e-423a-9421-294a2c043d22}
GoTestVolIdIdentity            {68147e15-d8bf-491d-85d5-98698fb3ee6c}
GoTestVolIdJunction            {7bbce513-361b-4ff4-aedb-09499749192a}
```

This list above includes several that `Mount-Go` did not actually itself create:
`GoTestRemoteFileServer` and `GoTestPeculiarFileServer` were defined manually.

> `Dismount-Go` deletes *all* environment variables called `GoTest*`.

To see which variables are defined in the current terminal session, run:
```PowerShell
dir env:GoTest* | sort Name
```

## Prefixes and Suffixes for Environment Variables

The above list of environment variables include the following line:
```PowerShell
GoTestSuffixes                 Guid;Drive;Identity;Junction;HardLink
```

These are the suffixes defined by `Mount-Go` and this variable is used
by `Dismount-Go` to dismount and delete just those virtual disk files that
it created.

Another use is by `Build-Go*` CmdLets. They may be able to filter
the tests they produce based on either a prefix or a suffix.

The following prefixes are defined by `Mount-Go` easily extracted from the above list:

|Prefix				|Description	|
|:--				|:--			|
|`Local`			|Local drive mappings for SMB shares, `\` stripped.
|`Peculiar`			|The full path to the peculiar directory on that disk.
|`Remote`			|The remote path for SMB shares.
|`Shared`			|The local folder that is shared by an SMB share.
|`VhdLink`			|The link or access path as a normal path, if present.
|`VhdRoot`			|The root of the drive as reported by `($vhd | Get-Partition).AccessPaths[0]` after setting up the partition.
|`VolId`			|The value of `($vhd | Get-Partition).Guid` for the virtual disk.

See `Get-Help Build-GoEvalSymlinksTests` for more information.
