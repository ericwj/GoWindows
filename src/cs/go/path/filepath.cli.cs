using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

using GoWindows.CSharp;

using Vanara.PInvoke;

using static GoWindows.CSharp.epi;
public partial class go {
	public partial interface path {
		public partial interface filepath {
			public class cli : filepath
			{
				public static readonly cli Instance = new cli();
				#region Constants
				public static readonly char Separator = Path.DirectorySeparatorChar;
				public static readonly char AltSeparator = Path.AltDirectorySeparatorChar;
				public static readonly char ListSeparator = Path.PathSeparator;
				public const string EmptyPath = null;
				public const string EmptyDir = null;
				public const string EmptyFile = null;
				public const string EmptyExt = null;
				public const string EmptyWin32Pattern = "*";
				public const string RelCurrentDir = ".";
				public static ReadOnlySpan<char> Separators => new [] {
					Path.DirectorySeparatorChar,
					Path.AltDirectorySeparatorChar
				};
				char filepath.Separator => Separator;
				char filepath.ListSeparator => ListSeparator;
				#endregion
				#region Variables
				public error ErrBadPattern => new err("syntax error in pattern");
				public error SkipDir => new err("skip this directory");
				#endregion
				#region Functions
				/// <summary>func Abs(path string) (string, error)</summary>
				public (string result, error error) Abs(string path) => string.IsNullOrEmpty(path) ? (null, go.Err(InvalidArgument)) : Try(path, AbsPrivate);
				private string AbsPrivate(string path) {
					var without = path.NormalizePrefix(out var prefix);
					var result = Path.GetFullPath(prefix + without);
					result = path.Substring(0, prefix.Length) + result.Substring(prefix.Length);
					return Clean(result);
				}
				/// <summary>func Base(path string) string</summary>
				public string Base(string path) {
					if (string.IsNullOrEmpty(path)) return EmptyFile;
					var without = path.NormalizePrefix(out var prefix);
					var result = without.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
					if (string.IsNullOrEmpty(without) && prefix.Length == 0)
						return Path.DirectorySeparatorChar.ToString();
					result = Path.GetFileName(prefix + without);
					if (string.IsNullOrEmpty(result)) return EmptyFile;
					return result;
				}
				private static readonly string two = "" + Separator + Separator;
				private static readonly string one = Separator.ToString();
				private static readonly string sd = $"{Separator}.";
				private static readonly string sdd = $"{Separator}..";
				private static readonly string ds = $".{Separator}";
				private static readonly string sds = $"{Separator}.{Separator}";
				private static readonly string invp = new string(Path.GetInvalidPathChars().OrderBy(c => c).ToArray());
				private static readonly string invf = new string(Path.GetInvalidFileNameChars().OrderBy(c => c).ToArray());
				private static readonly string invfp = new string((invp + invf).Distinct().OrderBy(c => c).ToArray());
				private static readonly string inv = Regex.Escape(
					new string( 
						Path.GetInvalidPathChars().Concat(
						Path.GetInvalidFileNameChars().Distinct())
					.ToArray()));
				private static string esc => Regex.Escape(Separator.ToString());
				private static readonly Regex parentPlusDots = new Regex(@$"(^|{esc})[^{esc}]+{esc}\.\.({esc}|$)");
				/// <summary>func Clean(path string) string</summary>
				public string Clean(string path) {
					if (string.IsNullOrEmpty(path)) return EmptyPath;
					var without = path.NormalizePrefix(out var prefix);
					if (string.IsNullOrEmpty(without)) return prefix;
					if (prefix.Length > 0) {
						return prefix + path.Substring(prefix.Length).ToDefaultSeparator();
					}
					var current = prefix + without.ToDefaultSeparator();
					var previous = current;
					var root = "";
					var isUnc = false;
					try {
						root = Path.GetPathRoot(current);
						isUnc = ShlwApi.PathIsUNC(root);
					} catch { }
					if (string.IsNullOrEmpty(root) && string.IsNullOrEmpty(current))
						return ".";
					do {
						previous = current;
						current = current.Substring(root.Length);

						current = current.TrimEnd(Path.DirectorySeparatorChar);
						current = parentPlusDots.Replace(current, one);
						if (current.EndsWith(sd)) current = current.Substring(0, current.Length - sd.Length);
						current = current.Replace(two, one, StringComparison.Ordinal);
						current = current.Replace(sds, one, StringComparison.Ordinal);
						var ends = root?.EndsWith(one) ?? false;
						if (current == ".")
							current = "";
						else if (ends && !isUnc) {
							while (current.StartsWith(one))
								current = current.Substring(one.Length);
							while (current.StartsWith(ds))
								current = current.Substring(2);
							if (current == ".." || current == ".")
								current = "";
						} else if (isUnc) {
							if (current == sd || current == sdd)
								current = "";
						} else {
							while (current.StartsWith(sds))
								current = current.Substring(2);
							if (current == sd)
								current = "";
						}
						current = root + current;
					} while (previous != current);

					if (current == "")
						return EmptyPath;
					else
						return current.SuppressEmpty();
				}
				/// <summary>func Dir(path string) string</summary>
				public string Dir(string path) {
					if (string.IsNullOrEmpty(path)) return EmptyDir;
					var without = path.NormalizePrefix(out var prefix);
					var normalized = prefix + without;
					var root = Path.GetPathRoot(normalized);
					var dir = Path.GetDirectoryName(normalized);
					var result = string.IsNullOrEmpty(dir) ? root : dir;
					if (result.StartsWith(prefix))
						result = path.Substring(0, prefix.Length) + result.Substring(prefix.Length);
					return string.IsNullOrEmpty(result) ? EmptyDir : result;
				}

				/// <summary>func EvalSymlinks(path string) (string, error)</summary>
				public (string result, error err) EvalSymlinks(string path) {
					if (string.IsNullOrEmpty(path)) return (EmptyPath, default(error));
					var without = path.ToDefaultSeparator().NormalizePrefix(out var prefix);
					var normalized = prefix + without;
					try {
						if (!Directory.Exists(normalized) && !File.Exists(normalized)) {
							var nrp =
								prefix.Length > 0 ? normalized :
								ShlwApi.PathIsUNC(normalized) ? @"\\?\UNC\" + normalized.Substring(2) :
								@"\\?\" + normalized;
							if (nrp != normalized) {
								if (Directory.Exists(nrp) || File.Exists(nrp))
									return (nrp, null);
							}
						} else {
							return (Clean(path), null);
						}
						Kernel32.SafeSearchHandle handle = null;
						try {
							handle = Kernel32.FindFirstFileEx(path,
								Kernel32.FINDEX_INFO_LEVELS.FindExInfoBasic,
								out var ffdata,
								Kernel32.FINDEX_SEARCH_OPS.FindExSearchNameMatch,
								default(IntPtr),
								default(Kernel32.FIND_FIRST));
							var hr = Marshal.GetHRForLastWin32Error();
							if (handle.IsInvalid && hr == FileNotFound) {
								handle.Dispose();
								handle = Kernel32.FindFirstFileEx(path,
									Kernel32.FINDEX_INFO_LEVELS.FindExInfoBasic,
									out ffdata,
									Kernel32.FINDEX_SEARCH_OPS.FindExSearchLimitToDirectories,
									default(IntPtr),
									default(Kernel32.FIND_FIRST));
								hr = Marshal.GetHRForLastWin32Error();
							}
							if (handle.IsInvalid) {
								if (hr == FileNotFound) hr = PathNotFound;
								var ex = Marshal.GetExceptionForHR(hr);
								return (null, go.Err(ex));
							}
						} finally {
							if (handle is object) handle.Dispose();
						}
					} catch (Exception ex) {
						return (null, go.Err(ex));
					}
					throw new NotSupportedException("Unreachable code reached.");
				}
				/// <summary>func Ext(path string) string</summary>
				public string Ext(string path) {
					if (string.IsNullOrEmpty(path)) return EmptyExt;
					var ext = Path.GetExtension(path.NormalizePrefix());
					if (string.IsNullOrEmpty(ext)) return EmptyExt;
					return ext;
				}
				/// <summary>func FromSlash(path string) string</summary>
				public string FromSlash(string path) {
					if (path is null || path.Length == 0)
						return EmptyPath;
					if (path.IndexOf('/') >= 0)
						path = path.Replace('/', Separator);
					return path;
				}
				/// <summary>func Glob(pattern string) (matches []string, err error)</summary>
				public (string[] matches, error err) Glob(string pattern) => Try(pattern, GlobPrivate, TranslatePatternErro);
				private go.error TranslatePatternErro(Exception exception) {
					if (exception is ArgumentException aex && aex.ParamName == "pattern") {
						return new go.err(exception.Message);
					} else
						return go.Err(exception);
				}
				private static readonly RegexOptions GlobRexRuntime = 0
					| RegexOptions.Singleline
					| RegexOptions.CultureInvariant;
				private static readonly RegexOptions GlobRexRo = 0
					| RegexOptions.Compiled
					| RegexOptions.Singleline
					| RegexOptions.CultureInvariant;
				private static readonly string RexRequiresEscape = string.Concat(
					from i in Enumerable.Range(0, 0x7f)
					let c = (char)i
					let s = c.ToString()
					where "\0\a\b\t\n\v\f\r".IndexOf(c) >= 0 || s != Regex.Escape(s)
					orderby c
					select s);
				internal const bool GlobCheckRanges = false;
				private static readonly string GlobEscape = Regex.Escape($"{Separator}{AltSeparator}");
				private static readonly string GlobPattern = $"[^{GlobEscape}]";
				private static readonly string GlobQuestion = GlobPattern + "{1}";
				private static readonly string GlobStar = GlobPattern + "*";
				private static readonly Regex GlobDotRex = new Regex("^\\.$", GlobRexRo);
				private static readonly Regex GlobRex = new Regex(
					@"(?<r>\[(?<n>\^?)(?<v>\\.|\\u[0-9a-fA-F]{4}|.)-(?<w>\\.|\\u[0-9a-fA-F]{4}|.)\])|(?<b>\\\\)|(?<f>/)|(?<x>\*)|(?<q>\?)|(?<a>\\\[)|(?<z>\\])|(?<u>\\u[0-9a-fA-F]{4})|(?<t>[^\\/\[\]\?\*]+)|(?<c>\\u[0-9a-fA-F]{4}|[^\[\]\\]|\\.)", GlobRexRo);
				private static readonly Regex GlobChar = new Regex(
					@"\\u(?<u>[0-9a-fA-F]{4})|\\(?<c>.)|(?<n>.)", GlobRexRo);
				private static string[] GlobPrivate(string pattern) {
					if (string.IsNullOrEmpty(pattern)) return null;
					var (rex, w32) = GlobPatternToWin32(pattern);
					var wd = Directory.GetCurrentDirectory();
					static IEnumerable<string> One(string value) { yield return value; }
					var query =
						from path in One(".").Concat(Directory.EnumerateFileSystemEntries(wd, w32, SearchOption.AllDirectories))
						let relative = Path.GetRelativePath(wd, path)
						where rex.IsMatch(relative)
						select relative;
					return query.OrderBy(x => x, StringComparer.Ordinal).ToArray();
				}
				public static (Regex regex, string pattern) GlobPatternToWin32(string pattern) {
					if (string.IsNullOrEmpty(pattern)) return (GlobDotRex, EmptyWin32Pattern);
					var status = TryGlobPatternToWin32(pattern, out var result, out var match, out var group, out var offender, out var index);
					string explanation;
					switch (status) {
					case PatternStatus.Success: return (new Regex(result.regex, GlobRexRuntime), result.pattern);
					default:
					case PatternStatus.Unexpected:				explanation = "The pattern failed validation."; break;
					case PatternStatus.NoMatch:					explanation = $"Unexpected {offender.ToDisplayChar()} in pattern"; break;
					case PatternStatus.InvalidEscape:			explanation = $"The character {offender.ToDisplayChar()} may not be escaped."; break;
					case PatternStatus.InvalidFileNameChar:		explanation = $"The syntax '{match.Value}' contains invalid file name character {offender.ToDisplayChar()}."; break;
					case PatternStatus.InvalidRange:			explanation = $"The character range specification '{match.Value}' is invalid.";  break;
					case PatternStatus.InvalidRangeCoverage:	explanation = $"The character range '{match.Value}' contains only invalid file name characters.";  break;
					case PatternStatus.InvalidRangeCharacter:	explanation = $"The character range '{match.Value}' contains invalid file name character {offender.ToDisplayChar()}."; break;
					case PatternStatus.InvalidReverseRange:		explanation = $"The character group '{match.Value}' is ordered in reverse."; break;
					}
					throw new ArgumentException(
						$"The pattern '{pattern}' is invalid at position {index}. {explanation}", nameof(pattern));
				}
				public enum PatternStatus
				{
					Success,
					Unexpected = -1,
					NoMatch = 1,
					InvalidEscape,
					InvalidFileNameChar,
					InvalidRange,
					InvalidRangeCharacter,
					InvalidReverseRange,
					InvalidRangeCoverage,
				}
				public static PatternStatus TryGlobPatternToWin32(string pattern,
					out (string regex, string pattern) result,
					out Match match,
					out Group group,
					out char offender,
					out int index)
				{
					PatternStatus status;
					static bool TryGetChar(string s, out char result, out int length, out char offender, out PatternStatus status) {
						var match = GlobChar.Match(s);
						result = default;
						length = match.Length;
						if (!match.Success) goto Fail;
						if (match.Index != 0) goto Fail;
						if (match.Groups[0].Length != s.Length) goto Fail;
						var group = match.Groups.Cast<Group>().Skip(1).First(g => g.Success);
						if (group is null) goto Fail;
						switch (group.Name) {
						case "u":
//						case "x": // |\\x(?<x>[0-9a-fA-F]{2,4}) // regex can't do this
							result = (char)int.Parse(group.Value, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
							return ValidateEscape(result, out offender, out status);
						case "c":
							result = group.Value.Single();
							if (result == '0')
								result = '\0';
							else {
								var i = "abtnvfr".IndexOf(result);
								if (i >= 0) result = (char)((int)'\a' + i);
							}
							return ValidateEscape(result, out offender, out status);
						case "n":
							result = match.Value.Single();
							return ValidateSingle(result, out offender, out status);
						default: goto Fail;
						}
					Fail:
						status = PatternStatus.Unexpected;
						offender = s.FirstOrDefault();
						return false;
					}
					if (string.IsNullOrEmpty(pattern)) {
						result = (GlobDotRex.ToString(), EmptyWin32Pattern);
						match = default;
						group = default;
						offender = default;
						index = default;
						return default;
					}
					static bool ValidateSingle(char c, out char offender, out PatternStatus status) {
						if (invfp.IndexOf(c) >= 0) {
							offender = c;
							status = PatternStatus.InvalidFileNameChar;
							return false;
						} else {
							offender = default;
							status = default;
							return true;
						}
					}
					static bool ValidateEscape(char c, out char offender, out PatternStatus status) {
						// don't allow specifying through \uhex4 any of *, ?,
						// invalid path or file name characters - usually ASCII 0-31 and :*?\/"<>|
						// or regular ASCII letters/digits
						// this does allow !#$%&'()+,-.;=@[]^_`{}~
						if (c == '?' || c == '*' || c == '/') {
							goto InvalidEscape2;
						} else if (invfp.IndexOf(c) >= 0) {
							offender = c;
							status = PatternStatus.InvalidFileNameChar;
							return false;
						} else if ((int)c < 0x80) {
							if (RexRequiresEscape.IndexOf(c) < 0) { // allow \$ \^ \[ \] \. etc
								goto InvalidEscape2;
							}
						}
						offender = default;
						status = default;
						return true;
					InvalidEscape2:
						offender = c;
						status = PatternStatus.InvalidEscape;
						return false;
					}
					static bool ValidateRange(char b, char e, out char offender, out PatternStatus status) {
						bool IsInRange(char c) => b <= c && c <= e;
						var faulted = false;
						var f = invf.FirstOrDefault(IsInRange);
						faulted = f != default || IsInRange(default);
						if (faulted) {
							if (b == e || (invf.IndexOf(b) + 1 == invf.IndexOf(e) && e - b <= 1)) {
								status = PatternStatus.InvalidRangeCoverage;
								offender = b;
								return false;
							}
#pragma warning disable CS0162 // Unreachable code detected
							if (GlobCheckRanges) {
								status = PatternStatus.InvalidFileNameChar;
								offender = f;
								return false;
							}
#pragma warning restore CS0162 // Unreachable code detected
						}
						offender = default;
						status = default;
						return true;
					}
					static bool ValidateText(string s, out char offender) {
						if (string.IsNullOrEmpty(s)) goto OK;
						var violators = invp + "\\*?";
						var span = s.AsSpan();
						ref var begin = ref Unsafe.AsRef(in span[0]);
						var len = span.Length;
						for (var i = 0; i < len; i++) {
							var c = Unsafe.Add(ref begin, i);
							var o = violators.IndexOf(c);
							if (o >= 0) {
								offender = violators[o];
								return false;
							}
						}
					OK:
						offender = default;
						return true;
					}

					var winb = new StringBuilder();
					var rexb = new StringBuilder();
					static void AddStar(StringBuilder sb) { if (sb.Length == 0 || sb[sb.Length - 1] != '*') sb.Append('*'); }
					index = 0;
					group = null;
					match = null;
					rexb.Append('^');
					while (index < pattern.Length) {
						match = GlobRex.Match(pattern, index);
						if (!match.Success) {
							offender = pattern[index];
							goto NoMatch;
						}
						var first = match.Groups[0];
						group = match.Groups.Cast<Group>().Skip(1).FirstOrDefault(g => g.Success);
						if (group is null) goto Unexpected;
						if (match.Index != index) {
							var length = match.Index - index;
							if (!AppendText(pattern.Substring(index, length), out offender)) goto InvalidFileNameChar;
							index += length;
							continue;
						}
						bool AppendText(string value, out char offender) {
							winb.Append(value);
							rexb.Append(Regex.Escape(value));
							return ValidateText(value, out offender);
						}

						switch (group.Name) {
						case "b":	winb.Append('\\');			rexb.Append(@"\\");			break;				// b: \		backslach
						case "f":	winb.Append('\\');			rexb.Append(@"/");			break;				// f: /		forward slash
						case "x":	AddStar(winb);				rexb.Append(GlobStar);		break;				// x: *		asterix
						case "q":	winb.Append('?');			rexb.Append(GlobQuestion);	break;				// q: ?		question mark
						case "a":	winb.Append("[");			rexb.Append(@"\[");			break;				// a: [		open
						case "z":	winb.Append("]");			rexb.Append(@"\]");			break;				// z: ]		close
						case "t":	if (!AppendText(group.Value, out offender)) goto InvalidFileNameChar; break;// t: text not matched otherwise
						case "u":
						case "c": {
							var remembered = index;
							var cs = group.Value;
							if (!TryGetChar(cs, out var c, out var length, out offender, out status))
								goto FailWithStatus;
									winb.Append(c);				rexb.Append(Regex.Escape(c.ToString()));			// c: \c	character
							break;
						}
						case "r": {
							var remembered = index;
							var negated = match.Groups["n"].Value != "";
							if (pattern[index] != '[') {
								offender = pattern[index];
								goto InvalidRange;
							}
							var vg = match.Groups["v"];
							index = vg.Index;
							var vs = vg.Value;
							if (!TryGetChar(vs, out var v, out var length, out offender, out status))
								if (GlobCheckRanges)
#pragma warning disable CS0162 // Unreachable code detected
									goto FailWithStatus;
#pragma warning restore CS0162 // Unreachable code detected
							index += length;
							if (pattern[index] != '-') {
								offender = pattern[index];
								goto InvalidRange;
							}
							index++; // -
							var wg = match.Groups["w"];
							if (index != wg.Index) {
								offender = pattern[index];
								goto InvalidRange;
							}
							var ws = wg.Value;
							if (!TryGetChar(ws, out var w, out length, out offender, out status))
								if (GlobCheckRanges)
#pragma warning disable CS0162 // Unreachable code detected
									goto FailWithStatus;
#pragma warning restore CS0162 // Unreachable code detected
							index += length;
							if (pattern[index] != ']') {
								offender = pattern[index];
								goto InvalidRange;
							}
							index++; // ]
							if (v > w) {
								index = remembered;
								offender = w;
								goto InvalidReverseRange;
							}
							if (index != match.Index + match.Length) {
								index--;
								offender = pattern[index];
								goto InvalidRange;
							}

							if (!ValidateRange(v, w, out offender, out status)) {
								index = remembered;
								goto FailWithStatus;
							}
							winb.Append("?");
							var negc = negated ? "^" : null;
							var vesc = v == ']' ? "\\]" : Regex.Escape(v.ToString());
							var wesc = w == ']' ? "\\]" : Regex.Escape(w.ToString());
							rexb.Append($"[{negc}{vesc}-{wesc}]");	// r: [a-z]	character range
							continue;
						}
						default: goto Unexpected;
						}
						index += first.Length;
					}
					rexb.Append('$');
					result = (rexb.ToString(), winb.ToString());
					offender = default;
					return default;

				NoMatch: status = PatternStatus.NoMatch; goto FailWithStatus;
				Unexpected: status = PatternStatus.Unexpected; offender = default; goto FailWithStatus;
				InvalidFileNameChar: status = PatternStatus.InvalidFileNameChar; goto FailWithStatus;
				InvalidRange: status = PatternStatus.InvalidRange; goto FailWithStatus;
				InvalidReverseRange: status = PatternStatus.InvalidReverseRange; goto FailWithStatus;
				FailWithStatus:
					result = default;
					return status;
				}
				/// <summary>func HasPrefix(p, prefix string) bool</summary>
				public bool HasPrefix(string p, string path) => throw new NotImplementedException();
				/// <summary>func IsAbs(path string) bool</summary>
				public bool IsAbs(string path) => string.IsNullOrEmpty(path) ? false : Path.IsPathFullyQualified(path.NormalizePrefix());
				/// <summary>func Join(elem ...string) string</summary>
				public string Join(params string[] paths) {
					var array = (
						from item in paths ?? Array.Empty<string>()
						where !string.IsNullOrEmpty(item)
						let normalized = item.NormalizePrefix()
						select normalized)
						.ToArray();
					var last = (from item in array.Reverse() where item.IsNoParsePrefix() select item).FirstOrDefault();
					var result = Path.Combine(array);
					if (last is object) {
						var a = result.NormalizePrefix(out var aprefix);
						var bprefix = "";
						var b = last?.NormalizePrefix(out bprefix);
						if (aprefix.Length > 0 && aprefix == bprefix) {
							result = last.Substring(0, aprefix.Length) + result.Substring(aprefix.Length);
						}
					}
					return Clean(result).SuppressEmpty();
				}
				/// <summary>func Match(pattern, name string) (matched bool, err error)</summary>
				public (bool matched, error error) Match(string pattern, string name)
					=> Try(pattern, x => MatchPrivate(x, name), TranslatePatternErro);
				private bool MatchPrivate(string pattern, string name) {
					if (string.IsNullOrEmpty(name) && string.IsNullOrEmpty(pattern)) return true;
					var (rex, w32) = GlobPatternToWin32(pattern);
					if (name is null) return false;
					return rex.IsMatch(name);
				}
				private static bool Match(Regex pattern, string name) => pattern.IsMatch(name);
				/// <summary>func Rel(basepath, targpath string) (string, error)</summary>
				public (string result, error error) Rel(string basepath, string targpath)
					=> string.IsNullOrEmpty(targpath)
					? (EmptyPath, default(error))
					: Try<(string basepath, string targpath), string>((basepath, targpath), x => Path.GetRelativePath(
						relativeTo: x.basepath.NormalizePrefix(),
						path: x.targpath.NormalizePrefix()));
				/// <summary>func Split(path string) (dir, file string)</summary>
				public (string dir, string file) Split(string path) {
					if (string.IsNullOrEmpty(path)) return (null, null);
					if (path.Last().IsDirectorySeparator()) return (path, string.Empty);
					var n = path.NormalizePrefix(out var prefix);
					var f = Path.GetFileName(n);
					var d = Path.GetDirectoryName(n);
					var r = Path.GetPathRoot(n);
					var result = d ?? r;
					if (prefix.Length > 0 && result.StartsWith(prefix))
						result = path.Substring(0, prefix.Length) + result.Substring(prefix.Length);
					return (result, f);
				}
				/// <summary>func SplitList(path string) []string</summary>
				public string[] SplitList(string path) =>
					string.IsNullOrEmpty(path) ? Array.Empty<string>() : path.Split(ListSeparator);

				/// <summary>func ToSlash(path string) string</summary>
				public string ToSlash(string path) {
					if (path is null || path.Length == 0)
						return EmptyPath;
					if (path.IndexOf(Path.DirectorySeparatorChar) >= 0)
						path = path.Replace(Separator, '/');
					if (Separator != Path.AltDirectorySeparatorChar && path.IndexOf(Path.AltDirectorySeparatorChar) >= 0)
						path = path.Replace(Separator, '/');
					return path;
				}
				/// <summary>func VolumeName(path string) string</summary>
				public string VolumeName(string path) => Path.GetPathRoot(path);

				private static readonly IEnumerable<(string path, os.FileInfo fi, error err)> emptyWalk =
					Enumerable.Empty<(string path, os.FileInfo fi, error err)>();
				/// <summary>func Walk(root string, walkFn WalkFunc) error</summary>
				public IEnumerable<(string path, os.FileInfo fi, error err)> Walk(string root, StrongBox<error> errorResult) {
					try {
						IEnumerable<(string path, os.FileInfo fi, error err)> Iterator(string root, DirectoryInfo di, StrongBox<error> errorResult) {
							var rel = Rel(root, di.FullName);
							if (rel.error is null)
								yield return (rel.result, new os.WrappedFileInfo(di), null);

							foreach (var child in Flat(root, di.FullName, errorResult))
								yield return child;
						}
						var di = new DirectoryInfo(root);
						if (!di.Exists) {
							errorResult.Value = Err(new DirectoryNotFoundException());
							return emptyWalk;
						}
						return Iterator(Directory.GetCurrentDirectory(), di, errorResult);
					} catch (Exception ex) {
						errorResult.Value = Err(ex);
						return Enumerable.Empty<(string, os.FileInfo, error)>();
					}
				}
				IEnumerable<(string workdir, os.FileInfo fi, error err)> Flat(string root, string current, StrongBox<error> errorResult) {
					using var searchHandle = Kernel32.FindFirstFileEx(@$"{current}\*",
						Kernel32.FINDEX_INFO_LEVELS.FindExInfoBasic,
						out var ffdata,
						Kernel32.FINDEX_SEARCH_OPS.FindExSearchNameMatch,
						lpSearchFilter: default,
						default(Kernel32.FIND_FIRST));
					if (searchHandle.IsInvalid) {
						var hr = Marshal.GetHRForLastWin32Error();
						var ex = Marshal.GetExceptionForHR(hr);
						Debug.WriteLine($"FindFirstFileEx failed. {ex.Message}");
						yield break;
					}
					static bool CheckDots(ref WIN32_FIND_DATA ffdata, Kernel32.SafeSearchHandle searchHandle) {
						var span = ffdata.cFileName.AsSpan();
						if (span.Length == 1 && span[0] == '.') {
							if (Kernel32.FindNextFile(searchHandle, out ffdata))
								span = ffdata.cFileName.AsSpan();
							else
								return false;
						}
						if (span.Length == 2 && span[1] == '.') {
							if (Kernel32.FindNextFile(searchHandle, out ffdata))
								span = ffdata.cFileName.AsSpan();
							else
								return false;
						}
						return true;
					}
					do {
						if (!CheckDots(ref ffdata, searchHandle)) yield break;
						var path = Path.Combine(current, ffdata.cFileName);
						var rel = Rel(root, path);
						var fi = new os.Win32FileInfo(ffdata);
						if (rel.error is null)
							yield return (rel.result, fi, null);
						if (fi.IsDir)
							foreach (var child in Flat(root, path, errorResult))
								yield return child;
					} while (Kernel32.FindNextFile(searchHandle, out ffdata));
				}
				#endregion
			}
		}
	}
}
