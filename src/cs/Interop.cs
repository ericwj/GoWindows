using System.Runtime.InteropServices;

namespace GoWindows.CSharp
{
	internal static class PowerShellKernel32
	{
		private const string Dll = "Kernel32.dll";
		[DllImport(Dll, SetLastError = true)]
		public static extern uint GetConsoleCP();
		[DllImport(Dll, SetLastError = true)]
		public static extern bool SetConsoleCP(uint cp);
		[DllImport(Dll, SetLastError = true)]
		public static extern uint GetConsoleOutputCP();
		[DllImport(Dll, SetLastError = true)]
		public static extern bool SetConsoleOutputCP(uint cp);
	}
	internal static class ShlwApi
	{
		private const string Dll = "ShlwApi.dll";
		[DllImport(Dll, CharSet = CharSet.Auto)]
		public static extern bool PathIsUNC([In] string path);
		[DllImport(Dll, CharSet = CharSet.Auto)]
		public static extern bool PathIsUNCServer([In] string path);
		[DllImport(Dll, CharSet = CharSet.Auto)]
		public static extern bool PathIsUNCServerShare([In] string path);
		[DllImport(Dll, CharSet = CharSet.Auto)]
		public static extern bool PathIsNetworkPath([In] string path);
		[DllImport(Dll, CharSet = CharSet.Auto)]
		public static extern int PathGetDriveNumber([In] string path);
	}
}
