using System;
using System.IO;

using static GoWindows.CSharp.epi;
public static partial class go
{
	public static os.FileInfo Wrap(this FileSystemInfo fsi) => new os.WrappedFileInfo(fsi);
	public partial interface os
	{
		public error Chdir(string path);
		public (string dir, error err) Getwd();

		public class cli : os
		{
			public static readonly os Instance = new cli();
			public error Chdir(string path) => Try(path, x => {
				Environment.CurrentDirectory = x;
				return true;
			}).err;

			public (string dir, error err) Getwd() => Try(default(object), x => Environment.CurrentDirectory);
		}
	}
}
