using System;
using System.IO;

namespace GoWindows.CSharp.go.os
{
	using FI = System.IO.FileInfo;
	using DI = System.IO.DirectoryInfo;
	using FSI = System.IO.FileSystemInfo;
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
		public WrappedFileInfo(string fullname) => fsi = File.Exists(fullname)
			? (FSI)new FI(fullname)
			: (FSI)new DI(fullname);
		public string Name => fsi.FullName;
		public long Size => fsi is FI fi ? fi.Length : 0;
		public FileMode Mode => throw new PlatformNotSupportedException();
		public DateTime ModTime => fsi.LastWriteTime;
		public bool IsDir => fsi is DI;
		public object Sys => fsi;
	}
	public enum FileMode : uint
	{
		// ...
	}
}
