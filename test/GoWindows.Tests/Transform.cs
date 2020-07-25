using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using GoWindows.CSharp;

using Xunit;

namespace GoWindows.Tests
{
	public class Transform
	{
		public enum Api
		{
			None,
			Separator,		
			ListSeparator,	
			Abs,			
			EvalSymlinks,	
			Glob,			
			Match,			
			Rel,			
			Base,			
			Clean,			
			Dir,			
			Ext,			
			FromSlash,		
			IsAbs,			
			Join,			
			SplitList,		
			ToSlash,		
			VolumeName,		
			Split,			
			Walk,			
		}
		private void UnaryFilePath(Api api, string path, string expected, int? errno = null, string[] paths = null) {
			var input = new Input {
				Api = $"filepath.{api}",
				Join = paths,
				Path = path,
				Path2 = path,
				Pattern = path,
			};
			var writer = new StringWriter();
			var output = epi.Transform(input, writer);
			var actual = output.Result as string;
				static string E(int? i) => i.HasValue ? i.ToString() : "(null)";
			if (errno.Equals(output.Errno))
				Assert.Equal(errno, output.Errno);
			else if ((errno == null) != (output.Errno == null))
				Assert.Equal(E(errno), E(output.Errno));

			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(@"\", @"\\?\UNC\server\share", @"/sharver/shardir/..", @"/sharverdir/..")]
		public void Join(string expected, params string[] paths) => UnaryFilePath(Api.Join, null, expected, null, paths);
		[Theory]
		[InlineData(@"//?/unC/server/share/..", @"\\?\UNC\server\share\..")]
		[InlineData(@"\\server\share", @"\\server\share")]
		[InlineData(@"/\?\volumE{00000000-0000-0000-0000-000000000000}/..", @"\\?\volumE{00000000-0000-0000-0000-000000000000}\..")]
		public void Abs(string path, string expected) => UnaryFilePath(Api.Abs, path, expected);
		[Theory]
		[InlineData(@"\\server\share", null)]
		[InlineData(@"\\?\server\share", @"share")]
		[InlineData(@"\\?\unc\server\share", null)]
		[InlineData(@"\\?\UNC\server\share", null)]
		public void Base(string path, string expected) => UnaryFilePath(Api.Base, path, expected);
		[Theory]
		[InlineData("c:", "c:")]
		[InlineData("c:.", "c:")]
		[InlineData("c:..", "c:..")]
		[InlineData("c:/.", @"c:\")]
		[InlineData("c:/..", @"c:\")]
		[InlineData(@"server\share\..", @"server")]
		[InlineData(@"\\server\share\..", @"\\server\share")]
		[InlineData(@"\??\unC/", @"\??\UNC\")]
		[InlineData(@"\??\c:\/sharver/shardir", @"\??\c:\\sharver\shardir")]
		[InlineData(@"\??\\/sharver/shardir", @"\??\\\sharver\shardir")]
		[InlineData(@"\\?\UNC\server\share\..", @"\\?\UNC\server\share\..")]
		public void Clean(string path, string expected) => UnaryFilePath(Api.Clean, path, expected);
		[Theory]
		[InlineData(@"\??\volumE{00000000-0000-0000-0000-000000000000}", null, 123)]
		[InlineData(@"/\?\c:/", @"\\?\c:\", null)]
		[InlineData(@"/\?\c:/.", null, 0x7b)]
		public void EvalSymlinks(string path, string expected, int? errno) => UnaryFilePath(Api.EvalSymlinks, path, expected, errno);
	}
}
