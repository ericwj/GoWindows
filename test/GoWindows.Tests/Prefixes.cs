using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using GoWindows.CSharp;

using Xunit;

namespace GoWindows.Tests
{
	public class Prefixes
	{
		[Theory]
		[InlineData(@"\\.\unc\localhost\share", true, 8)]
		[InlineData(@"//?/unc/localhost\share", true, 8)]
		[InlineData(@"\??\unc\localhost\share", true, 4)]
		[InlineData(@"\\?\C:\", true, 4)]
		[InlineData(@"\\.\C:\", true, 4)]
		[InlineData(@"\??\C:\", true, 4)]
		[InlineData(@"\..\C:\", false, 0)]
		public void ShouldBePrefixes(string path, bool expected, int length) {
			var actual = epi.TryGetNoParsePrefix(path, out var actualLength);
			Assert.Equal(expected, actual);
			Assert.Equal(length, actualLength);
		}
	}
}
