using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading.Tasks;

using Xunit;

namespace GoWindows.Tests
{
	public class PathFilepath
	{
		private readonly go.os os = go.os.cli.Instance;
		private readonly go.path.filepath filepath = go.path.filepath.cli.Instance;
		private const string cwd = "<cwd>";
		public PathFilepath() {
			
		}

		[Fact]
		public void ChdirDrives() {
			foreach (var drive in DriveInfo.GetDrives()) {

			}
		}
		
		[Theory]
		[InlineData(@"C:\", @"C:\")]
		[InlineData(@"C:\\", @"C:\")]
		[InlineData(@"C:\.", @"C:\")]
		[InlineData(@"C:\..", @"C:\")]
		[InlineData(@"C:\.\", @"C:\")]
		[InlineData(@"C:\..\", @"C:\")]
		[InlineData(@"C:\Users\..\", @"C:\")]
		[InlineData(@"C:\NonExisting\..\", @"C:\")]
		[InlineData(@"\\?\C:\", @"\\?\C:\")]
		[InlineData(@"\\?\C:\\", @"\\?\C:\")]
//		[InlineData(@"\\?\C:\.", @"\\?\C:\.")]			// 87 Parameter incorrect
//		[InlineData(@"\\?\C:\..", @"\\?\C:\..")]		// 123 The filename, directory name, or volume label syntax is incorrect
		[InlineData(@"\\?\C:\.\", @"\\?\C:\")]
//		[InlineData(@"\\?\C:\..\", @"\\?\C:\..\")]		// 123 The filename, directory name, or volume label syntax is incorrect
		[InlineData(@"\\?\C:\Users\..\", @"\\?\C:\")]
		[InlineData(@"\\?\C:\NonExisting\..\", @"\\?\C:\")]
		public void ChdirSucceeds(string path, string expected) {
			var current = Environment.CurrentDirectory;
			try {
				var err = os.Chdir(path);
				var actual = Environment.CurrentDirectory;
				Assert.Null(err);
				Assert.Equal(expected, actual);
			} finally {
				Environment.CurrentDirectory = current;
			}
		}

		[Theory]
		[InlineData(@"C:\")]
		public void GetwdSucceeds(string expected) {
			var current = Environment.CurrentDirectory;
			try {
				Environment.CurrentDirectory = expected;
				var (actual, err) = os.Getwd();
				Assert.Null(err);
				Assert.Equal(expected, actual);
			} finally {
				Environment.CurrentDirectory = current;
			}
		}

		[Fact]
		public void SeparatorIsEqual() => Assert.Equal(
			Path.DirectorySeparatorChar,
			filepath.Separator);

		[Fact]
		public void ListSeparatorIsEqual() => Assert.Equal(
			Path.PathSeparator,
			filepath.ListSeparator);

		[Theory]
		[InlineData(null, null, unchecked((ushort)0x800700A0))]
		[InlineData("", null, unchecked((ushort)0x800700A0))]
		[InlineData(@"C:\", @"C:\", null)]
		public void AbsSucceeds(string path, string expected, uint? code) {
			if (expected is object) expected = expected.Replace(cwd, Directory.GetCurrentDirectory());
			var (actual, err) = filepath.Abs(path);
			if (code == null) Assert.Null(err);
			Assert.Equal(expected, actual);
			Assert.Equal(code.ToInt32(), err?.Code);
		}

		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:\", null)]
		[InlineData(@"C:\A", "A")]
		[InlineData(@"\\?\..", null)]
		public void BaseSucceeds(string path, string expected) {
			var actual = filepath.Base(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:\", @"C:\")]
		public void CleanSucceeds(string path, string expected) {
			var actual = filepath.Clean(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:\", @"C:\")]
		[InlineData(@"C:\A", @"C:\")]
		public void DirSucceeds(string path, string expected) {
			var actual = filepath.Dir(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:\\Doesn't Exist", null, 3, "The system cannot find the path specified. (0x80070003)")]
		[InlineData(@"C:\", @"C:\")]
		public void EvalSymLinksSucceeds(string path, string expected, int? code = null, string message = null) {
			var actual = filepath.EvalSymlinks(path);
			Assert.Equal(expected, actual.result);
			Assert.Equal(code, actual.err?.Code);
			Assert.Equal(message, actual.err?.Error);
		}
		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:\", null)]
		[InlineData(@"C:\A", null)]
		[InlineData(@"C:\A.ext", ".ext")]
		public void ExtSucceeds(string path, string expected) {
			var actual = filepath.Ext(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:/", @"C:\")]
		public void FromSlashSucceeds(string path, string expected) {
			var actual = filepath.FromSlash(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, true)]
		[InlineData("", true)]
		[InlineData(@"*", false, ".", "file.txt")]
		[InlineData(@"*.*", false, ".", "file.txt")]
		[InlineData(@"f*.*", false, "file.txt")]
		[InlineData(@"F*.*", false)]
		[InlineData(@"f???.txt", false, "file.txt")]
		[InlineData(@"f[e-l][e-l][e-l].txt", false, "file.txt")]
		public void GlobSucceeds(string pattern, bool @null, params string[] expected) {
			if (@null && 0 == (expected?.Length ?? 0)) expected = null;
			var cwd = Environment.CurrentDirectory;
			var temp = Path.GetTempFileName();
			if (File.Exists(temp)) File.Delete(temp);
			var dir = Directory.CreateDirectory(temp);
			const string file = nameof(file) + ".txt"; // file.txt
			var full = Path.Combine(dir.FullName, file);
			File.WriteAllText(full, nameof(GlobSucceeds));
			var fi = new FileInfo(full);
			try {
				Environment.CurrentDirectory = temp;
				var actual = filepath.Glob(pattern);
				Assert.Equal(expected, actual.matches);
			} finally {
				Environment.CurrentDirectory = cwd;
				Directory.Delete(dir.FullName, recursive: true);
			}
		}
		[Theory]
		[InlineData(null, false)]
		[InlineData("", false)]
		[InlineData(@"C:\", true)]
		public void IsAbsSucceeds(string path, bool expected) {
			var actual = filepath.IsAbs(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null)]
		[InlineData(null, null)]
		[InlineData(null, "")]
		[InlineData(@"C:\", @"C:\")]
		public void JoinSucceeds(string expected, params string[] paths) {
			var actual = filepath.Join(paths);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null, true)]
		[InlineData(null, "", true)]
		[InlineData("", null, true)]
		[InlineData("", "", true)]
		[InlineData(@"C:\\", @"C:\", true)]
		public void MatchSucceeds(string pattern, string name, bool expected) {
			var (actual, err) = filepath.Match(pattern, name);
			Assert.Null(err);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null, null)]
		[InlineData("", "", null)]
		[InlineData(@"C:\", @"C:\", @".")]
		public void RelSucceeds(string basepath, string targpath, string expected) {
			var (actual, err) = filepath.Rel(basepath, targpath);
			Assert.Null(err);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null, null)]
		[InlineData("", null, null)]
		[InlineData(@"C:\", @"C:\", @"")]
		[InlineData(@"C:\A", @"C:\", @"A")]
		[InlineData(@"C:\A\", @"C:\A\", @"")]
		[InlineData(@".\A", @".", @"A")]
		public void SplitSucceeds(string path, string edir, string efile) {
			var actual = filepath.Split(path);
			var expected = (edir, efile);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null)]
		[InlineData("")]
		[InlineData(@"?* ; ", "?* ", " ")]
		public void SplitListSucceeds(string path, params string[] expected) {
			var actual = filepath.SplitList(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:\", @"C:/")]
		public void ToSlashSucceeds(string path, string expected) {
			var actual = filepath.ToSlash(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(null, null)]
		[InlineData("", null)]
		[InlineData(@"C:", @"C:")]
		[InlineData(@"C:\", @"C:\")]
		[InlineData(@"C:\A", @"C:\")]
		[InlineData(@"\\?\Volume{BC850FAE-CFCD-4783-9093-222AD1635ADE}", @"\\?\Volume{BC850FAE-CFCD-4783-9093-222AD1635ADE}")]
		[InlineData(@"\\?\Volume{BC850FAE-CFCD-4783-9093-222AD1635ADE}\", @"\\?\Volume{BC850FAE-CFCD-4783-9093-222AD1635ADE}\")]
		[InlineData(@"\\?\Volume{BC850FAE-CFCD-4783-9093-222AD1635ADE}\A", @"\\?\Volume{BC850FAE-CFCD-4783-9093-222AD1635ADE}\")]
		public void VolumeNameSucceeds(string path, string expected) {
			var actual = filepath.VolumeName(path);
			Assert.Equal(expected, actual);
		}
		[Fact]
		public void WalkSucceeds() {
			var temp = Path.GetTempFileName();
			if (File.Exists(temp)) File.Delete(temp);
			var dir = Directory.CreateDirectory(temp);
			const string file = nameof(file) + ".txt";
			var full = Path.Combine(dir.FullName, file);
			File.WriteAllText(full, nameof(WalkSucceeds));
			var fi = new FileInfo(full);

			var wd = Directory.GetCurrentDirectory();
			Directory.SetCurrentDirectory(dir.FullName);
			try {
				try {
					var result = new StrongBox<go.error>();
					var actual = filepath.Walk(dir.FullName, result);
					var expected = new [] {
						(".", dir.Wrap(), default(go.error)),
						(file, fi.Wrap(), default(go.error))
					};
					var aenum = actual.GetEnumerator();
					var eenum = expected.Cast<(string path, go.os.FileInfo fi, go.error err)>().GetEnumerator();
					while (true) {
						var emove = eenum.MoveNext();
						Assert.Equal(emove, aenum.MoveNext());
						if (!emove) break;

						var e = eenum.Current;
						var a = aenum.Current;
						Assert.Equal(e.path, a.path);
						Assert.Equal(e.fi is null, a.fi is null);
						Assert.Equal(e.err is null, a.err is null);
						if (e.fi is object) {
							Assert.Equal(e.fi.Name, a.fi.Name);
							Assert.Equal(e.fi.IsDir, a.fi.IsDir);
						}
						if (e.err is object) {
							Assert.Equal(e.err.Code, a.err.Code);
							Assert.Equal(e.err.Error, a.err.Error);
						}
					}
				} finally {
					Directory.SetCurrentDirectory(wd);
				}
			} finally {
				Directory.Delete(dir.FullName, recursive: true);
			}
		}
	}
}
