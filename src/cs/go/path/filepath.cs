using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Threading;

public partial class go
{
	public partial interface path
	{
		/// <summary>Plublic API as an interface such that it can be swapped for another
		/// <para>Using C#'s feature Default Interface Implementation for now</para></summary>
		public partial interface filepath
		{
			/// <summary>type WalkFunc</summary>
			public delegate error WalkFunc(string path, os.FileInfo info, error error);
			#region Constants
			public char Separator { get; }
			public char ListSeparator { get; }
			#endregion
			#region Variables
			public error ErrBadPattern => new err("syntax error in pattern");
			public error SkipDir => new err("skip this directory");
			#endregion
			#region Functions
			/// <summary>func Abs(path string) (string, error)</summary>
			public (string result, error error) Abs(string path);
			/// <summary>func Base(path string) string</summary>
			public string Base(string path);
			/// <summary>func Clean(path string) string</summary>
			public string Clean(string path);
			/// <summary>func Dir(path string) string</summary>
			public string Dir(string path);
			/// <summary>func EvalSymlinks(path string) (string, error)</summary>
			public (string result, error err) EvalSymlinks(string path);
			/// <summary>func Ext(path string) string</summary>
			public string Ext(string path);
			/// <summary>func FromSlash(path string) string</summary>
			public string FromSlash(string path);
			/// <summary>func Glob(pattern string) (matches []string, err error)</summary>
			public (string[] matches, error err) Glob(string pattern);
			/// <summary>func HasPrefix(p, prefix string) bool</summary>
			public bool HasPrefix(string p, string path);
			/// <summary>func IsAbs(path string) bool</summary>
			public bool IsAbs(string path);
			/// <summary>func Join(elem ...string) string</summary>
			public string Join(params string[] path);
			/// <summary>func Match(pattern, name string) (matched bool, err error)</summary>
			public (bool matched, error error) Match(string pattern, string name);
			/// <summary>func Rel(basepath, targpath string) (string, error)</summary>
			public (string result, error error) Rel(string basepath, string targpath);
			/// <summary>func Split(path string) (dir, file string)</summary>
			public (string dir, string file) Split(string path);
			/// <summary>func SplitList(path string) []string</summary>
			public string[] SplitList(string path);
			/// <summary>func ToSlash(path string) string</summary>
			public string ToSlash(string path);
			/// <summary>func VolumeName(path string) string</summary>
			public string VolumeName(string path);
			/// <summary>func Walk(root string, walkFn WalkFunc) error</summary>
			public IEnumerable<(string path, os.FileInfo fi, error err)> Walk(string root, StrongBox<error> result);
			#endregion
		}
	}
}
