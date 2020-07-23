using System;
using System.Runtime.InteropServices;

public partial class go
{
	public const int FacilityMask = 0x7ff_0000;
	public const int FacilityWin32 = 0x0007_0000;
	public static int? ToInt32(this uint? code) => code == null ? (int?)null : unchecked((int)code.Value);
	public static int LastErrorForWin32(this int hr)
		=> FacilityWin32 == (hr & FacilityMask)
		? (ushort)hr
		: hr;
	
	public static error Err(string message, int? code = null)
		=> new err(message, code);
	public static error Err(Exception ex)
		=> ex is null ? null : new err(ex.Message, ex.HResult.LastErrorForWin32());
	public static error Err(int hr)
		=> hr == 0
		? throw new ArgumentException("Cannot create an error from HRESULT 0x00000000. The HRESULT denotes success.")
		: Err(Marshal.GetExceptionForHR(hr));
	public interface error
	{
		string Error { get; }
		int? Code { get; }
	}
	public class err : error
	{
		public err(string message, int? code = null) {
			this.Error = message;
			this.Code = code;
		}
		public string Error { get; }
		public int? Code { get; }
	}
}
