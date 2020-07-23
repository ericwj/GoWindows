using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace GoWindows.CSharp
{
	using static epi;
	internal struct Input
	{
		public int Index { get; set; }
		public string Api { get; set; }
		public string Path { get; set; }
		public string Path2 { get; set; }
		public string Pattern { get; set; }
		public string[] Join { get; set; }
		public string[] Traits { get; set; }
	}
	internal partial struct Output
	{
		public int Index { get; set; }
		public int? Errno { get; set; }
		public object Result { get; set; }
		public string Name { get; set; }
		public string Error { get; set; }
		public bool? IsItem { get; set; }
		public string[] Traits { get; set; }
	}
	internal static class epi
	{
		/// <summary>HRESULT_FROM_WIN32(ERROR_INVALID_FUNCTION)</summary>
		public const int InvalidFunction = unchecked((int)0x80070001);
		/// <summary>HRESULT_FROM_WIN32(ERROR_INVALID_DATA)</summary>
		public const int InvalidData = unchecked((int)0x8007000D);
		/// <summary>HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)</summary>
		public const int FileNotFound = unchecked((int)0x80070002);
		/// <summary>HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)</summary>
		public const int PathNotFound = unchecked((int)0x80070003);
		public const int NetworkPathNotFound = unchecked((int)0x80070035);
		public const int NetworkNameNotFound = unchecked((int)0x80070043);
		/// <summary>HRESULT_FROM_WIN32(ERROR_BAD_ARGUMENTS)</summary>
		public const int InvalidArgument = unchecked((int)0x800700A0);

		public static int Win32From(int hr) => (ushort)hr;
		public static int Win32Error(this Exception ex) => Win32From(ex?.HResult ?? 0);

		private static go.os os = go.os.cli.Instance;
		private static go.path.filepath filepath = go.path.filepath.cli.Instance;

		public static readonly JsonSerializerOptions options = new JsonSerializerOptions() {
			IgnoreNullValues = true,
			PropertyNameCaseInsensitive = true,
			PropertyNamingPolicy = null,
			Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
		};
		private static int Main(string[] args) {
			const string wd = "--workdir";
			const string db = "--debug";
			static bool Is(string x, string y) => string.Equals(x, y, StringComparison.OrdinalIgnoreCase);
			static bool IsWorkDir(string arg) => Is(wd, arg);
			static bool IsDebugArg(string arg) => Is(db, arg);
			if (args.Any(IsWorkDir)) {
				var i = args.Select((arg, index) => IsWorkDir(arg) ? index : -1).Where(x => x >= 0).Single();
				Directory.SetCurrentDirectory(args[i + 1]);
				args = args.Except(args.Where((arg, index) => index == i || index == i + 1)).ToArray();
			}
			if (args.Any(IsDebugArg)) {
				try {
					if (Debugger.IsAttached)
						Debugger.Break();
					else
						Debugger.Launch();
				} catch {
					Console.Error.WriteLine("Failed to start JIT debugging.");
				}
				args = args.Except(args.Where(IsDebugArg)).ToArray();
			}
			if (args.Any()) {
				// in debug, command line arguments are configured through json; unescape some
				var json = string.Join(" ", args)
					.Replace("'", "\"")
					.Replace("\\", @"\\");
				return ActualMain(new[] { json }, Console.Out);
			} else
				return ActualMain(EnumerateLines(Console.In), Console.Out);
		}
		private static IEnumerable<string> EnumerateLines(TextReader reader) {
			while (true) {
				var result = reader.ReadLine();
				if (result is null) yield break;
				yield return result;
			}
		}
		private static int ActualMain(IEnumerable<string> reader, TextWriter writer) {
			foreach (var line in reader) {
				Input input;
				try {
					input = JsonSerializer.Deserialize<Input>(line, options);
				} catch (Exception ex) {
					writer.WriteLine($"Failed to deserialize input '{line}': 0x{ex.HResult:x8}: {ex.Message}");
					return ex.HResult;
				}
				Output output;
				try {
					output = Transform(input, writer);
				} catch (Exception ex) {
					writer.WriteLine($"Failed to process input '{line}': 0x{ex.HResult:x8}: {ex.Message}");
					return ex.HResult;
				}
				output.Index = input.Index;
				output.Traits = input.Traits;
				string json;
				try {
					json = JsonSerializer.Serialize(output, options);
				} catch (Exception ex) {
					writer.WriteLine($"Failed to serialize output after processing '{line}': 0x{ex.HResult:x8}: {ex.Message}");
					return ex.HResult;
				}
				writer.WriteLine(json);
			}
			return 0;
		}
		public static Output Transform(Input input, TextWriter output) {
			switch (input.Api) {
			case "os.Getwd":				return os.Getwd();
			case "os.Chdir":				return os.Chdir(input.Path).Void();
			case "filepath.Separator":		return filepath.Separator;
			case "filepath.ListSeparator":	return filepath.ListSeparator;
			case "filepath.Abs":			return filepath.Abs(input.Path);
			case "filepath.EvalSymlinks":	return filepath.EvalSymlinks(input.Path);
			case "filepath.Glob":			return filepath.Glob(input.Pattern);
			case "filepath.Match":			return filepath.Match(input.Pattern, input.Path);
			case "filepath.Rel":			return filepath.Rel(input.Path, input.Path2);
			case "filepath.Base":			return filepath.Base(input.Path);
			case "filepath.Clean":			return filepath.Clean(input.Path);
			case "filepath.Dir":			return filepath.Dir(input.Path);
			case "filepath.Ext":			return filepath.Ext(input.Path);
			case "filepath.FromSlash":		return filepath.FromSlash(input.Path);
			case "filepath.IsAbs":			return filepath.IsAbs(input.Path);
			case "filepath.Join":			return filepath.Join(input.Join);
			case "filepath.SplitList":		return filepath.SplitList(input.Path);
			case "filepath.ToSlash":		return filepath.ToSlash(input.Path);
			case "filepath.VolumeName":		return filepath.VolumeName(input.Path);
			case "filepath.Split":			return filepath.Split(input.Path);
			case "filepath.Walk":			return Walk(input.Path, input, output).Void();
			default:						return Output.NotImplemented;
			}
		}
		private static (object ignore, go.error err) Void(this go.error err)
			=> (default(object), err);
		public static string SuppressEmpty(this string text) => string.IsNullOrEmpty(text) ? null : text;
		public static string[] SuppressEmpty(this string[] text) =>
			text is null ? Array.Empty<string>() :
			text.Any(t => t is null) ? text.Select(t => t ?? "").ToArray() :
			text;
		private static go.error Walk(string root, Input input, TextWriter output) {
			var result = Try((root, input, output), x => WalkImpl(x.root, x.input, x.output));
			return result.result ?? result.err;
		}
		private static go.error WalkImpl(string root, Input input, TextWriter output) {
			var result = new StrongBox<go.error>();
			foreach (var (rel, fi, err) in filepath.Walk(root, result)) {
				var json = JsonSerializer.Serialize(new Output {
					Errno = err?.Code == 0 ? (int?)null : err?.Code,
					Error = err?.Error,
					Result = rel,
					Name = fi.Name,
					IsItem = true,
					Index = input.Index,
					Traits = input.Traits,
				}, options);
				output.WriteLine(json);
			}
			return result.Value;
		}
		public static (T result, go.error err) Try<Args, T>(Args args, Func<Args, T> function, Func<Exception, go.error> translate = null) {
			var x = TryCore(args, function);
			return (x.result, translate?.Invoke(x.exception) ?? go.Err(x.exception));
		}
		public static (T result, Exception exception) TryCore<Args, T>(Args args, Func<Args, T> function) {
			try {
				var result = function(args);
				return (result, null);
			} catch (Exception ex) {
				return (default(T), ex);
			}
		}
		public static (T[] result, go.error err) Try<Args, T>(Args args, Func<Args, IEnumerable<T>> function, Func<Exception, go.error> translate = null) {
			var x = TryCore(args, function);
			return (x.result, translate?.Invoke(x.exception) ?? go.Err(x.exception));
		}
		public static (T[] result, Exception exception) TryCore<Args, T>(Args args, Func<Args, IEnumerable<T>> function) {
			try {
				var result = function(args);
				return (result?.ToArray(), null);
			} catch (Exception ex) {
				return (default(T[]), ex);
			}
		}
		public static string ToDisplayChar(this char c) {
			switch (char.GetUnicodeCategory(c)) {
			case UnicodeCategory.Control: {
				char d = default;
				if (c == 0)
					d = '0';
				else if (c >= '\a' && c <= '\r')
					d = "abtnvfr"[c - '\a'];
				if (d != default)
					return $"\\u{(int)c:x4} '\\{d}'";
				goto case UnicodeCategory.Surrogate;
			}
			case UnicodeCategory.EnclosingMark:
			case UnicodeCategory.Format:
			case UnicodeCategory.LineSeparator:
			case UnicodeCategory.ModifierLetter:
			case UnicodeCategory.ModifierSymbol:
			case UnicodeCategory.NonSpacingMark:
			case UnicodeCategory.OtherNotAssigned:
			case UnicodeCategory.ParagraphSeparator:
			case UnicodeCategory.PrivateUse:
			case UnicodeCategory.SpacingCombiningMark:
			case UnicodeCategory.Surrogate:
				return $"\\u{(int)c:x4}";
			case UnicodeCategory.SpaceSeparator:
				if (c == ' ') goto default;
				goto case UnicodeCategory.Surrogate;
			default:
				return $"\\u{(int)c:x4} '{c}'";
			}
		}
		public static string TrimStart(this string @this, string trim) =>
			string.IsNullOrEmpty(@this) ||
			string.IsNullOrEmpty(trim) ||
			@this.Length < (trim?.Length ?? 0) ? @this : @this.Substring(trim.Length);
		public static string NormalizePrefix(this string @this) {
			if (string.IsNullOrEmpty(@this)) return @this;
			@this = @this.NormalizePrefix(out var prefix);
			return prefix + @this;
		}
		public static string NormalizePrefix(this string @this, out string prefix) {
			if (string.IsNullOrEmpty(@this) || !TryGetNoParsePrefix(@this, out var length)) {
				prefix = "";
				return @this;
			}
			prefix = @this.Substring(0, length).ToUpperInvariant().ToDefaultSeparator();
			return @this.Substring(length);
		}
		public static string ToDefaultSeparator(this string @this)
			=> @this.IndexOf(Path.AltDirectorySeparatorChar) < 0
			? @this
			: @this.Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar);
		private static bool IsDirectorySeparator(this char @this)
			=> @this == Path.DirectorySeparatorChar || @this == Path.AltDirectorySeparatorChar;
		public static bool IsNoParsePrefix(this string @this)
			=> @this.AsSpan().IsNoParsePrefix();
		public static bool IsNoParsePrefix(this ReadOnlySpan<char> @this)
			=> @this.TryGetNoParsePrefix(out _);
		public static bool TryGetNoParsePrefix(this string @this, out int length)
			=> @this.AsSpan().TryGetNoParsePrefix(out length);
		private static bool TryGetNoParsePrefix(this ReadOnlySpan<char> @this, out int length) {
			if (@this.Length < 4) goto Fail;
			// |··|
			if (!@this[0].IsDirectorySeparator() || !@this[3].IsDirectorySeparator()) goto Fail;
			// ··.·
			if (@this[2] == '.' && @this[1].IsDirectorySeparator()) goto Four;
			// ··?·
			if (@this[2] != '?') goto Fail;
			// ·?·· or ·|··
			if (!@this[1].IsDirectorySeparator() && @this[1] != '?') goto Fail;
			// ||?|unc|
			if (@this.Length >= 8 && @this[7].IsDirectorySeparator()) {
				if (@this.Slice(4).StartsWith("unc", StringComparison.OrdinalIgnoreCase)) {
					length = 8;
					return true;
				}
			}
		Four:
			length = 4;
			return true;
		Fail:
			length = default;
			return false;
		}
	}
	internal partial struct Output {
		public static readonly Output NotImplemented = new Output {
			Errno = InvalidData,
			Error = "The Api parameter was not recognized or the Api is not implemented.",
		};
		public static implicit operator Output(char c) => new Output {
			Result = c.ToString()
		};
		public static implicit operator Output((object ignore, go.error err) x) => new Output {
			Errno = x.err?.Code == 0 ? (int?)null : x.err?.Code,
			Error = x.err?.Error,
		};
		public static implicit operator Output(string result) => new Output {
			Result = result
		};
		public static implicit operator Output((string result, go.error err) x) => new Output() {
			Errno = x.err?.Code == 0 ? (int?)null : x.err?.Code,
			Error = x.err?.Error,
			Result = x.result
		};
		public static implicit operator Output((string directory, string file) x) => new Output() {
			Result = x.directory,
			Name = x.file,
		};
		public static implicit operator Output(bool result) => new Output() {
			Result = result
		};
		public static implicit operator Output((bool result, go.error err) x) => new Output() {
			Errno = x.err?.Code == 0 ? (int?)null : x.err?.Code,
			Error = x.err?.Error,
			Result = x.result,
		};
		public static implicit operator Output(string[] result) => new Output() {
			Result = result
		};
		public static implicit operator Output((string[] result, go.error err) x) => new Output {
			Errno = x.err?.Code == 0 ? (int?)null : x.err?.Code,
			Error = x.err?.Error,
			Result = x.result,
		};
	}
}
