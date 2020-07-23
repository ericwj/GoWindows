using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading;

public partial class go {
	public partial interface path {
		public partial interface filepath {
			public class fake : filepath
			{
				private readonly os os;
				public fake(os os) => this.os = os;
				#region Constants
				public char Separator => '\\';
				public char ListSeparator => ':';
				#endregion
				#region Variables
				public error ErrBadPattern => new err("syntax error in pattern");
				public error SkipDir => new err("skip this directory");
				#endregion
				#region Functions
				/// <summary>func Abs(path string) (string, error)</summary>
				public (string result, error error) Abs(string path) => (!Path.IsPathRooted(path) ? Clean(new DirectoryInfo(Path.Combine(Directory.GetCurrentDirectory(), path)).FullName) : Clean(new DirectoryInfo(path).FullName), default);
				/// <summary>func Base(path string) string</summary>
				public string Base(string path) => Path.GetFileName(path);
				/// <summary>func Clean(path string) string</summary>
				public string Clean(string path) => path;
				/// <summary>func Dir(path string) string</summary>
				public string Dir(string path) => Path.GetDirectoryName(path);
				/// <summary>func EvalSymlinks(path string) (string, error)</summary>
				public (string result, error err) EvalSymlinks(string path) => (path, Err(null));
				/// <summary>func Ext(path string) string</summary>
				public string Ext(string path) => Path.GetExtension(path);
				/// <summary>func FromSlash(path string) string</summary>
				public string FromSlash(string path) => path?.Replace('/', Separator);
				/// <summary>func Glob(pattern string) (matches []string, err error)</summary>
				public (string[] matches, error err) Glob(string pattern) => (Directory.EnumerateFileSystemEntries(Directory.GetCurrentDirectory(), pattern).ToArray(), null);
				/// <summary>func HasPrefix(p, prefix string) bool</summary>
				public bool HasPrefix(string p, string path) => new Random().NextDouble() < 0.5;
				/// <summary>func IsAbs(path string) bool</summary>
				public bool IsAbs(string path) => Path.IsPathRooted(path);
				/// <summary>func Join(elem ...string) string</summary>
				public string Join(params string[] path) => Path.Combine(path);
				/// <summary>func Match(pattern, name string) (matched bool, err error)</summary>
				public (bool matched, error error) Match(string pattern, string path) => (path?.StartsWith(pattern) ?? false, null);
				/// <summary>func Rel(basepath, targpath string) (string, error)</summary>
				public (string result, error error) Rel(string basepath, string targpath) => (Path.GetRelativePath(basepath, targpath), null);
				/// <summary>func Split(path string) (dir, file string)</summary>
				public (string dir, string file) Split(string path) => (Dir(path), Base(path));
				/// <summary>func SplitList(path string) []string</summary>
				public string[] SplitList(string path) => path?.Split(ListSeparator) ?? Array.Empty<string>();
				/// <summary>func ToSlash(path string) string</summary>
				public string ToSlash(string path) => path?.Replace(Separator, '/');
				/// <summary>func VolumeName(path string) string</summary>
				public string VolumeName(string path) => Path.GetPathRoot(path);
				/// <summary>func Walk(root string, walkFn WalkFunc) error</summary>
				public error Walk(string root, WalkFunc walkFn) {
					if (walkFn is null) return null;
					foreach (var entry in Directory.EnumerateFileSystemEntries(root, "*.*", SearchOption.AllDirectories))
						walkFn(entry, new os.WrappedFileInfo(entry), null);
					return null;
				}
				public IEnumerable<(string path, os.FileInfo fi, error err)> Walk(string root, StrongBox<error> errorResult) {
					try {
						IEnumerable<(string path, os.FileInfo fi, error err)> Iterator(DirectoryInfo di, StrongBox<error> errorResult) {
							foreach (var entry in di.EnumerateFileSystemInfos("*.*", SearchOption.AllDirectories)) {
								var rel = Rel(root, entry.FullName);
								yield return (rel.result, new os.WrappedFileInfo(entry), null);
							}
						}
						var di = new DirectoryInfo(root);
						return Iterator(di, errorResult);
					} catch (Exception ex) {
						errorResult.Value = Err(ex);
						return Enumerable.Empty<(string, os.FileInfo, error)>();
					}
				}
				#endregion
			}
		}
	}
}
