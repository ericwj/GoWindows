using System;
using System.IO;

using Xunit;

namespace GoWindows.Tests
{
	using static go.path.filepath.cli;
	public class MatchTests
	{
		[Theory]
//		[InlineData("*", @"[^\\\/]*", "*")]
//		[InlineData("?", @"[^\\\/]{1}", "?")]
//		[InlineData(".", @"\.", ".")]
//		[InlineData("[a]", @"\.", ".")]
		[InlineData(@"\[*\]?.txt\\[a-z]/[^A-Z]/[\u03b1-\u03b8][\u00e0-\u00ef]",
			@"^\[[^\\/]*\][^\\/]{1}\.txt\\[a-z]/[^A-Z]/[α-θ][à-ï]$",
			@"[*]?.txt\?\?\??")]
		[InlineData(@"Position10C:\\",
			@"^Position10C:\\$",
			@"Position10C:\")]
		[InlineData(@"\\",		@"^\\$",		@"\")]
		[InlineData(@"\$",		@"^\$$",		@"$")]
		[InlineData(@"[)-+]",	@"^[\)-\+]$",	@"?")]
		[InlineData(@"[\)-\+]", @"^[\)-\+]$",	@"?")]
		[InlineData(@"[[-]]",	@"^[\[-\]]$",	@"?")]
		[InlineData(@"C:\\",	@"^C:\\$",		@"C:\")]
		public void ToWin32Pattern(string input, string eregex, string epattern) {
			var (result, apattern) = go.path.filepath.cli.GlobPatternToWin32(input);
			var aregex = result.ToString();
			Assert.Equal(epattern, apattern);
			Assert.Equal(eregex, aregex);
		}
		[Theory]
		[InlineData(@"[A-z]",	"r",	@"[A-z]",		@"[A-z]",		'\\', 0, PatternStatus.InvalidRangeCharacter)]
		[InlineData(@"[\[-\]]",	"r",	@"[\[-\]]",		@"[\[-\]]",		'\\', 0, PatternStatus.InvalidRangeCharacter)]
		public void ToWin32Depends(string input, string name, string match, string group, char offender, int index, PatternStatus status) {
			var astatus = TryGlobPatternToWin32(input, out var result,
				out var amatch,
				out var agroup,
				out var aoffender,
				out var aindex);
			if (!go.path.filepath.cli.GlobCheckRanges) {
				Assert.Equal(PatternStatus.Success, astatus);
				return;
			}
			Assert.Equal(name, agroup?.Name);
			Assert.Equal(match, amatch.Value);
			Assert.Equal(group, agroup?.Value);
			Assert.Equal(offender, aoffender);
			Assert.Equal(status, astatus);
		}
		[Theory]
		[InlineData(@"Position10[b-a]",	"r",	@"[b-a]",		@"[b-a]",		'a',  1, PatternStatus.InvalidReverseRange)]
		[InlineData(@"[""-""]",	"r",	@"[""-""]",		@"[""-""]",		'"',  1, PatternStatus.InvalidRangeCoverage)]
		[InlineData(@"[b-a]",	"r",	@"[b-a]",		@"[b-a]",		'a',  1, PatternStatus.InvalidReverseRange)]
		[InlineData(@"\",		null,	@"",			null,			'\\', 0, PatternStatus.NoMatch)]
		[InlineData(@"\t",		"c",	@"\t",			@"\t",			'\t', 0, PatternStatus.InvalidFileNameChar)]
		[InlineData(@"\~",		"c",	@"\~",			@"\~",			'~',  0, PatternStatus.InvalidEscape)]
		[InlineData(@"\/",		"c",	@"\/",			@"\/",			'/',  0, PatternStatus.InvalidEscape)]
		[InlineData(@"\?",		"c",	@"\?",			@"\?",			'?',  1, PatternStatus.InvalidEscape)]
		[InlineData(@"\*",		"c",	@"\*",			@"\*",			'*',  1, PatternStatus.InvalidEscape)]
		[InlineData(@"C:\B",	"c",	@"\B",			@"\B",			'B',  2, PatternStatus.InvalidEscape)]
		[InlineData(@"\u0009",	"u",	@"\u0009",		@"\u0009",		'\t', 0, PatternStatus.InvalidFileNameChar)]
		public void ToWin32Failures(string input, string name, string match, string group, char offender, int index, PatternStatus status) {
			var astatus = TryGlobPatternToWin32(input, out var result,
				out var amatch,
				out var agroup,
				out var aoffender,
				out var aindex);
			Assert.Equal(name, agroup?.Name);
			Assert.Equal(match, amatch.Value);
			Assert.Equal(group, agroup?.Value);
			Assert.Equal(offender, aoffender);
			Assert.Equal(status, astatus);
		}
		[Theory]
		[InlineData("\\")]
		[InlineData(nameof(Path.GetInvalidPathChars))]
		[InlineData(nameof(Path.GetInvalidPathChars), true)]
		public void ToWin32PatternFails(string input, bool oneByOne = false) {
			switch (input) {
			case nameof(Path.GetInvalidFileNameChars): input = new string(Path.GetInvalidFileNameChars()); break;
			case nameof(Path.GetInvalidPathChars): input = new string(Path.GetInvalidPathChars()); break;
			}
			if (oneByOne)
				foreach (var c in input)
					Assert.Throws<ArgumentException>(() => go.path.filepath.cli.GlobPatternToWin32(c.ToString()));
			else
				Assert.Throws<ArgumentException>(() => go.path.filepath.cli.GlobPatternToWin32(input));
		}
	}
}
