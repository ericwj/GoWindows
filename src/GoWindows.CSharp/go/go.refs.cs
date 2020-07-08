namespace GoWindows.CSharp.go
{
	/// <summary>Not strictly matches but good enough</summary>
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
