using System;
using System.IO;
using System.Linq;

namespace GoWindows.CSharp.go.path
{
	/// <summary>type WalkFunc</summary>
	public delegate err WalkFunc(string path, os.FileInfo info, error error);
	/// <summary>Plublic API as an interface such that it can be swapped for another
	/// <para>Using C#'s feature Default Interface Implementation for now</para></summary>
	public interface filepath
	{
		#region Constants
		public char Separator => '\\';
		public char ListSeparator => ':';
		#endregion
		#region Variables
		public err ErrBadPattern => new err("syntax error in pattern");
		public err SkipDir => new err("skip this directory");
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
		public string EvalSymlinks(string path) => path;
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
		public (string message, error error) Rel(string basepath, string targpath) => (Path.GetRelativePath(basepath, targpath), null);
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
		#endregion
	}
}
