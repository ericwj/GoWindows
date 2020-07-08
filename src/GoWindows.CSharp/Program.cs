using System;
using System.Collections.Generic;
using System.Linq;

using GoWindows.CSharp.go;
using GoWindows.CSharp.go.path;

namespace GoWindows.CSharp
{
	using static Console;
	/// <summary>
	/// Reads commands and arguments from standard input and executes the specified go API calls.
	/// <para>For example to call <see cref="go.path.filepath.Rel(string, string)"/>,
	/// the program expects both the name and the arguments to be matched by name:</para>
	/// <code>
	/// \n
	/// Rel\n
	/// basepath: value\n
	/// targpath: value\n
	/// end
	/// </code>
	/// <para>The response will look like this:</para>
	/// <para><code>
	/// \n
	/// message: bla\n
	/// error: (n/a)\n
	/// </code></para>
	/// <para>Special values are</para>
	/// <list type="bullet">
	/// <item><para><c>#errors#</c> for errors, to distinguish between them and normal strings</para></item>
	/// <item><para><c>(n/a)</c> for null strings</para></item>
	/// <item><para>
	/// For string arrays:
	/// <code>
	/// paramname: item1\n
	/// paramname: item2\n
	/// paramname: (n/a)\n
	/// paramname: end
	/// </code>
	/// </para></item>
	/// </list>
	/// <para>Where \n is the operating system newline character(s).</para>
	/// </summary>
	internal class Program
	{
		/// <summary>Marks the end of the <see cref="Join(string[])"/> argument 'paths' like so: "paths: &lt;end&gt;".
		/// <para>Marsk the end of a command parameter list when this appears at the start of a line.</para></summary>
		public const string EndOfList = "end";
		/// <summary>Write this a few times and be sure to get booted.</summary>
		public const string QuitAlready = "bye";
		public const string Null = "(n/a)";
		private static err EmptyWalk(	string root, go.os.FileInfo info, error err) => null;
		private static err DefaultWalk(	string root, go.os.FileInfo info, error err) {
			switch (err) {
			case null:	WriteLine($"{nameof(DefaultWalk)}: {info.Name}");		break;
			default:	WriteLine($"{nameof(DefaultWalk)}: #{err.Error}#");		break;
			}
			return null;
		}
		private static int Main(string[] args) {
			filepath impl;
			if (!args.Any() || args.Any(arg => arg == "fake"))
				impl = new fake();
			else
				throw new NotImplementedException();

			while (true) {
			StartOver:
				var line = ReadLine();
				if (line is null) goto EndOfStream;
				// wait for some kind of separator - a blank line
				if (line != "")	{
					if (line == QuitAlready) return -1;
					WriteLine($"Expected newline, received: '{line}'.");
					continue;
				}
				// expect public API name
				line = ReadLine();
				if (line is null) goto EndOfStream;

				string basepath = null, targpath = null,
					p = null, pattern = null, path = null,
					root = null, walkfn = null;
				string[] paths = null;
				WalkFunc walk;

				var command = line;
				string[] arguments;
				// Collect the parameter names expected
				switch (command) {
				case null: goto EndOfStream;
				case nameof(filepath.Separator):		arguments = Array.Empty<string>(); break;
				case nameof(filepath.ListSeparator):	arguments = Array.Empty<string>(); break;
				case nameof(filepath.ErrBadPattern):	arguments = Array.Empty<string>(); break;
				case nameof(filepath.SkipDir):			arguments = Array.Empty<string>(); break;
				case nameof(filepath.Abs):				arguments = new [] { nameof(path) }; break;
				case nameof(filepath.Base):				arguments = new [] { nameof(path) }; break;
				case nameof(filepath.Clean):			arguments = new [] { nameof(path) }; break;
				case nameof(filepath.Dir):				arguments = new [] { nameof(path) }; break;
				case nameof(filepath.EvalSymlinks):		arguments = new [] { nameof(path) }; break;
				case nameof(filepath.Ext):				arguments = new [] { nameof(path) }; break;
				case nameof(filepath.FromSlash):		arguments = new [] { nameof(path) }; break;
				case nameof(filepath.Glob):				arguments = new [] { nameof(path) }; break;
				case nameof(filepath.HasPrefix):		arguments = new [] { nameof(p), nameof(path) }; break;
				case nameof(filepath.IsAbs):			arguments = new [] { nameof(path) }; break;
				case nameof(filepath.Join):				arguments = new [] { nameof(paths) }; break;
				case nameof(filepath.Match):			arguments = new [] { nameof(pattern), nameof(path) }; break;
				case nameof(filepath.Rel):				arguments = new [] { nameof(basepath), nameof(targpath) }; break;
				case nameof(filepath.Split):			arguments = new [] { nameof(path) }; break;
				case nameof(filepath.SplitList):		arguments = new [] { nameof(path) }; break;
				case nameof(filepath.ToSlash):			arguments = new [] { nameof(path) }; break;
				case nameof(filepath.VolumeName):		arguments = new [] { nameof(path) }; break;
				case nameof(filepath.Walk):				arguments = new [] { nameof(root), nameof(walkfn) }; break;
				default:
					WriteLine($"Invalid public API name, did not collect arguments for '{command}'.");
					continue;
				}
				// Expect one parameter on each successive line, except for 'paths' which is multiple lines starting with 'paths: ' and the last one is 'paths: <end>'
				foreach (var expected in arguments) {
					line = ReadLine();
					if (line is null) goto EndOfStream;
					if (!TryParse(line, out var temp, expected)) goto InvalidArgument;
					switch (expected) {
					case nameof(basepath):	basepath = temp; break;
					case nameof(targpath):	targpath = temp; break;
					case nameof(p):			p = temp; break;
					case nameof(pattern):	pattern = temp; break;
					case nameof(path):		path = temp; break;
					case nameof(root):		root = temp; break;
					case nameof(walkfn):	walkfn = temp; break;
					case nameof(paths):
						var list = new List<string>();
						do {
							list.Add(temp);
							line = ReadLine();
							if (line is null) goto EndOfStream;
						} while (TryParse(line, out temp, expected));
						if (temp != EndOfList) goto InvalidArgument;
						break;
					}
				InvalidArgument:
					WriteLine($"Expected '{expected}: <value>' got '{line}'.");
					goto StartOver;
				}
				// resolve the string walkfn to an actual WalkFunc implementation
				switch (walkfn) {
				case null: walk = null; break;
				case nameof(EmptyWalk): walk = EmptyWalk; break;
				case nameof(DefaultWalk): walk = DefaultWalk; break;
				default:
					WriteLine($"A '{nameof(WalkFunc)}' called '{walkfn}' is not recognized.");
					goto StartOver;
				}
				// define return value variables
				string message = null, result = null, dir = null, file = null;
				char Separator = default, ListSeparator = default; // '\0'
				error err = null, ErrBadPattern = null, SkipDir = null;
				bool yes = default;
				string[] split = null, matches = null;

				// now collect the result values
				switch (command) {
				case null: goto EndOfStream;
				case nameof(filepath.Separator):		Separator			= impl.Separator;				Report(command, (nameof(result), Separator));						break;
				case nameof(filepath.ListSeparator):	ListSeparator		= impl.ListSeparator;			Report(command, (nameof(result), ListSeparator));					break;
				case nameof(filepath.ErrBadPattern):	ErrBadPattern		= impl.ErrBadPattern;			Report(command, (nameof(result), ErrBadPattern));					break;
				case nameof(filepath.SkipDir):			SkipDir				= impl.SkipDir;					Report(command, (nameof(result), SkipDir));							break;
				case nameof(filepath.Abs):				(message, err)		= impl.Abs(path);				Report(command, (nameof(message), message), (nameof(err), err));	break;
				case nameof(filepath.Base):				result				= impl.Base(path);				Report(command, (nameof(result), result));							break;
				case nameof(filepath.Clean):			result				= impl.Clean(path);				Report(command, (nameof(result), result));							break;
				case nameof(filepath.Dir):				result				= impl.Dir(path);				Report(command, (nameof(result), result));							break;
				case nameof(filepath.EvalSymlinks):		result				= impl.EvalSymlinks(path);		Report(command, (nameof(result), result));							break;
				case nameof(filepath.Ext):				result				= impl.Ext(path);				Report(command, (nameof(result), result));							break;
				case nameof(filepath.FromSlash):		result				= impl.FromSlash(path);			Report(command, (nameof(result), result));							break;
				case nameof(filepath.Glob):				(matches, err)		= impl.Glob(path);				Report(command, (nameof(result), result));							break;
				case nameof(filepath.HasPrefix):		yes					= impl.HasPrefix(p, path);		Report(command, (nameof(yes), yes));								break;
				case nameof(filepath.IsAbs):			yes					= impl.IsAbs(path);				Report(command, (nameof(yes), yes));								break;
				case nameof(filepath.Join):				result				= impl.Join(paths);				Report(command, (nameof(result), result));							break;
				case nameof(filepath.Match):			(yes, err)			= impl.Match(pattern, path);	Report(command, (nameof(yes), yes), (nameof(err), err));			break;
				case nameof(filepath.Rel):				(message, err)		= impl.Rel(basepath, targpath);	Report(command, (nameof(message), message), (nameof(err), err));	break;
				case nameof(filepath.Split):			(dir, file)			= impl.Split(path);				Report(command, (nameof(dir), dir), (nameof(file), file));			break;
				case nameof(filepath.SplitList):		split				= impl.SplitList(path);			Report(command, (nameof(split), split));							break;
				case nameof(filepath.ToSlash):			result				= impl.ToSlash(path);			Report(command, (nameof(result), result));							break;
				case nameof(filepath.VolumeName):		result				= impl.VolumeName(path);		Report(command, (nameof(result), result));							break;
				case nameof(filepath.Walk):				err					= impl.Walk(root, walk);		Report(command, (nameof(result), result));							break;
				default:
					WriteLine($"Invalid public API name, did not execute '{command}'.");
					continue;
				}
				line = ReadLine();
				if (line is null) goto EndOfStream;
				if (line != EndOfList)
					WriteLine($"Expected '{EndOfList}', received: '{line}'.");
			}
		EndOfStream:
			WriteLine("End of stream. Exiting.");
			return 0;
		}
		private static void Report(string command, params (string name, object value)[] args) {
			WriteLine(); // success/we got here
			WriteLine(command);
			foreach (var arg in args) {
				Write(arg.name);
				Write(": ");
				switch (arg.value) {
				case bool b: WriteLine(b ? "true" : "false"); break;
				case char c: WriteLine(Format(c.ToString())); break;
				case string s: WriteLine(Format(s)); break;
				case err r: WriteLine($"#{r.Error}#"); break;
				case string[] strings:
					if ((strings?.Length ?? 0) == 0) {
						WriteLine(EndOfList);
						break;
					}
					WriteLine(Format(strings[0]));
					for (var i = 1; i < strings.Length; i++)
						WriteLine($"{arg.name}: {Format(strings[i])}");
					WriteLine($"{arg.name}: {EndOfList}");
					break;
				}
			}
			WriteLine(EndOfList);
		}
		private static string Format(string value) => value ?? Null;
		private static bool TryParse(string line, out string result, string expected) {
			if (line is null) goto Fail;
			var i = line.IndexOf(':');
			if (i < 0) goto Fail;
			if (line.Length < i + 2) goto Fail; // : and space required
			var actual = line.Substring(0, i);
			if (expected != actual) goto Fail;
			result = line.Substring(i + 2);
			if (result == Null) result = null;
			return true;
		Fail:
			result = null;
			return false;
		}
	}
}
