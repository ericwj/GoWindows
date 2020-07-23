using System;
using System.IO;

using FI = System.IO.FileInfo;
using DI = System.IO.DirectoryInfo;
using FSI = System.IO.FileSystemInfo;
using Vanara.PInvoke;
using Vanara.Extensions;

public partial class go
{
	public partial interface os {
		public interface FileInfo
		{
			// tbd, lets say it has a name
			public string Name { get; }
			public long Size { get; }
			public FileMode Mode { get; }
			public DateTime ModTime { get; }
			public bool IsDir { get; }
			public object Sys { get; }
		}
		public class WrappedFileInfo : FileInfo
		{
			private readonly FSI fsi;
			public WrappedFileInfo(string fullname) : this(File.Exists(fullname)
				? (FSI)new FI(fullname)
				: (FSI)new DI(fullname)) { }
			public WrappedFileInfo(FSI fsi) => this.fsi = fsi;
			public string Name => fsi.Name;
			public long Size => fsi is FI fi ? fi.Length : 0;
			public FileMode Mode => throw new PlatformNotSupportedException();
			public DateTime ModTime => fsi.LastWriteTime;
			public bool IsDir => fsi is DI;
			public object Sys => fsi;
		}
		public class Win32FileInfo : FileInfo
		{
			private readonly WIN32_FIND_DATA found;
			public Win32FileInfo(WIN32_FIND_DATA found) => this.found = found;
			public string Name => Path.GetFileName(found.cFileName);
			public long Size => (long)found.FileSize;
			public FileMode Mode => throw new PlatformNotSupportedException();
			public DateTime ModTime => found.ftLastWriteTime.ToDateTime(DateTimeKind.Local);
			public bool IsDir => 0 != (found.dwFileAttributes & FileAttributes.Directory);
			public object Sys => found;
		}
		public enum FileMode : uint
		{
			// ...
		}
	}
}
