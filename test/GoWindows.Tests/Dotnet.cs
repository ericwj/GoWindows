using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;

using Vanara.PInvoke;

using Xunit;

namespace GoWindows.Tests
{
	public class Dotnet
	{
		[Theory]
		[InlineData(@"D:\", @"C:\", @"D:\")]
		[InlineData(@"\\?\C:\Users", @"\\?\C:\", "Users")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\Users", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}", "Users")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\Users", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\", "Users")]
		public void Combine(string expected, params string[] paths) {
			var actual = Path.Combine(paths);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(@"\\?\.", @"\\?\.")]
		[InlineData(@"\\?\C:\Users\..", @"\\?\C:\Users\..")]
		public void GetFullPath(string path, string expected) {
			if (expected is object) expected = expected.Replace(PWD, Environment.CurrentDirectory);
			var actual = Path.GetFullPath(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(@"C:\", @"D:\", @"D:\")]
		public void GetRelativePath(string root, string target, string expected) {
			var actual = Path.GetRelativePath(root, target);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(@"\\?\UNC\localhost\share", @"\\?\UNC\localhost\share")]
		[InlineData(@"\\?\unc\localhost\share", @"\\?\unc\localhost\share")] // dotnet/runtime#39793
		[InlineData(@"\\localhost\share", @"\\localhost\share")]
		[InlineData(@"\\localhost\share\Users", @"\\localhost\share")]
		[InlineData(@"C:", @"C:")]
		[InlineData(@"C:\", @"C:\")]
		[InlineData(@"C:\Users", @"C:\")]
		[InlineData(@"\\?\C:", @"\\?\C:")]
		[InlineData(@"\\?\C:\", @"\\?\C:\")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\")]
		[InlineData(@"\\?\C:\Users", @"\\?\C:\")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\Users", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\")]
		public void GetPathRoot(string path, string expected) {
			var actual = Path.GetPathRoot(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(@"\\?\UNC\localhost\share", null)]
		[InlineData(@"//?/UNC/localhost/share", null)]
		[InlineData(@"\\?\unc\localhost\share", @"\\?\unc\localhost")]
		[InlineData(@"\\?\..", null)]
		[InlineData(@"\\localhost\share", null)]
		[InlineData(@"\\localhost\share\Users", @"\\localhost\share")]
		[InlineData(@"C:", null)]
		[InlineData(@"C:\", null)]
		[InlineData(@"C:\Users", @"C:\")]
		[InlineData(@"\\?\C:", null)]
		[InlineData(@"\\?\C:\", null)]
		[InlineData(@"\\?\C:\Users", @"\\?\C:\")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}", null)]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\", null)]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\Users", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\")]
		public void GetDirectoryName(string path, string expected) {
			var actual = Path.GetDirectoryName(path);
			Assert.Equal(expected, actual);
		}
		[Theory]
		[InlineData(@"\\localhost\share", @"\\localhost\share")]
		[InlineData(@"\\localhost\share\Users", @"\\localhost\share\Users")]
		[InlineData(@"C:", PWD)]
		[InlineData(@"C:\", @"C:\")]
		[InlineData(@"C:\Users", @"C:\Users")]
		[InlineData(@"\\?\C:", @"\\?\C:")]
		[InlineData(@"\\?\C:\", @"\\?\C:\")]
		[InlineData(@"\\?\C:\Users", @"\\?\C:\Users")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\Users", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\Users")]
		public void DirectoryInfoFullName(string path, string expected) {
			if (expected == PWD) {
				expected = Directory.GetCurrentDirectory();
				if (!expected.StartsWith("C:")) expected = null;
			}
			var actual = new DirectoryInfo(path).FullName;
			Assert.Equal(expected, actual);
		}
		public const string PWD = "<PWD>";
		[Theory]
		[InlineData(@"\\localhost\share", null)]
		[InlineData(@"\\localhost\share\Users", @"\\localhost\share")]
		[InlineData(@"C:", PWD)]
		[InlineData(@"C:\", null)]
		[InlineData(@"C:\Users", @"C:\")]
		[InlineData(@"\\?\C:", null)]
		[InlineData(@"\\?\C:\", null)]
		[InlineData(@"\\?\C:\Users", @"\\?\C:\")]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}", null)]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\", null)]
		[InlineData(@"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\Users", @"\\?\Volume{9B0BF51E-9438-44DF-B616-B0DF2C3B9C60}\")]
		public void DirectoryInfoParentFullName(string path, string expected) {
			if (expected == PWD) {
				expected = Path.GetDirectoryName(Directory.GetCurrentDirectory());
				if (!expected.StartsWith("C:")) expected = null;
			}
			var actual = new DirectoryInfo(path).Parent?.FullName;
			Assert.Equal(expected, actual);
		}

		[Fact]
		public void EnumerateFilesWithDotDot() {
			var expected = new[] {
				@"..\pagefile.sys"
			};
			var root = @"C:\Users";
			var actual = Directory.EnumerateFiles(
				root,
				@"..\pagefile.sys",
				SearchOption.TopDirectoryOnly)
				.Select(x => Path.GetRelativePath(root, x))
				.ToArray();
			Assert.Equal(expected, actual);
		}
		private const string NtfsEnableDirCaseSensitivity = nameof(NtfsEnableDirCaseSensitivity);
		private static bool TrySetCaseSensitivityGlobal(bool reset, ref int? oldValue) {
			const string fspath = @"SYSTEM\CurrentControlSet\Control\FileSystem";
			var fs = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(fspath);
			var o = fs.GetValue(NtfsEnableDirCaseSensitivity, null);
			var value = o is null ? (int?)null : (int)o;
			if (reset) {
				if (oldValue == null)
					fs.DeleteValue(NtfsEnableDirCaseSensitivity);
				else if (value != oldValue)
					fs.SetValue(NtfsEnableDirCaseSensitivity, oldValue.Value);
				return true;
			} else {
				oldValue = value;
				if (value.HasValue && (1 & value.Value) == 1) return true;
				if (oldValue == null)
					fs.SetValue(NtfsEnableDirCaseSensitivity, 1);
				else
					fs.SetValue(NtfsEnableDirCaseSensitivity, 1 | oldValue.Value);
				return true;
			}
		}
		private static bool TrySetDirectoryCaseSensitivity(bool enable, string path) {
			var status = enable ? "enable" : "disable";
			var fsutilpsi = new ProcessStartInfo("fsutil",
				$"file SetCaseSensitiveInfo \"{path}\" {status}") {
				CreateNoWindow = true,
				LoadUserProfile = false,
				RedirectStandardError = true,
				RedirectStandardOutput = true,
				UseShellExecute = false,
			};
			var fsutil = Process.Start(fsutilpsi);
			var @out = fsutil.StandardOutput.ReadToEnd();
			var err = fsutil.StandardError.ReadToEnd();
			fsutil.WaitForExit();
			if (!string.IsNullOrEmpty(@out)) Debug.WriteLine(@out);
			if (!string.IsNullOrEmpty(err)) Debug.WriteLine($"ERROR: {err}");
			return fsutil.ExitCode == 0 && string.IsNullOrEmpty(err);
		}
		/// <summary>Modifying the registry key will trip if not elevated.
		/// The following PowerShell commands can be used instead of elevating:
		/// <code>
		/// Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name NtfsEnableDirCaseSensitivity
		/// # this will divide by zero => have to pick enabled (1) resp. disabled (0)
		/// Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name NtfsEnableDirCaseSensitivity -Type DWord -Value (1/0)
		/// Remove-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name NtfsEnableDirCaseSensitivity
		/// </code>
		/// </summary>
		[Fact]
		public void EnumerateFilesCaseSensitiveDir() {
			var cwd = Environment.CurrentDirectory;
			var path = Environment.GetEnvironmentVariable("TEMP");
			path = Path.Combine(path, nameof(EnumerateFilesCaseSensitiveDir));
			path += $"-{new Random().Next():x8}";
			int? NtfsEnableDirCaseSensitivity = null;

			try { 
				Directory.CreateDirectory(path);
				try {
					Environment.CurrentDirectory = path;
					try {
						Assert.True(TrySetCaseSensitivityGlobal(reset: false, ref NtfsEnableDirCaseSensitivity));
						try {
							Assert.True(TrySetDirectoryCaseSensitivity(enable: true, path));
							File.WriteAllText("file.txt", "lowercase");
							File.WriteAllText("FILE.txt", "uppercase");
							string[] expected = null;
							using (var searchHandle = Kernel32.FindFirstFileEx(@$"{path}\f*",
								Kernel32.FINDEX_INFO_LEVELS.FindExInfoBasic,
								out var ffdata,
								Kernel32.FINDEX_SEARCH_OPS.FindExSearchNameMatch,
								lpSearchFilter: default,
								Kernel32.FIND_FIRST.FIND_FIRST_EX_CASE_SENSITIVE)) {

								var results = new List<string>();
								while (!searchHandle.IsInvalid) {
									results.Add(Path.GetRelativePath(path, ffdata.cFileName));
									if (!Kernel32.FindNextFile(searchHandle, out ffdata)) break;
								}
								expected = results.ToArray();
							} // FindClose; searchHandle.handle = default;

							var actual = Directory
								.EnumerateFileSystemEntries(path, "f*.*", new EnumerationOptions {
									MatchCasing = MatchCasing.CaseSensitive
									})
								.Select(file => Path.GetRelativePath(path, file))
								.ToArray();
							Assert.Equal(expected, actual);
						} finally {
							Assert.True(TrySetCaseSensitivityGlobal(reset: true, ref NtfsEnableDirCaseSensitivity));
						}
					} finally {
						Environment.CurrentDirectory = cwd;
					}
				} finally {
					Directory.Delete(path, recursive: true);
				}
			} catch (UnauthorizedAccessException ex) {
				throw new InvalidOperationException("This test must be run elevated.", ex);
			}
		}
	}
}
