using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

using GoWindows.CSharp;

using Xunit;

namespace GoWindows.Tests
{
	public class JsonSer
	{
		[Fact]
		public void Deserialize() {
			var json = "{'Api':'filepath.Abs','Path':'.'}".Replace("'", "\"");
			var options = new JsonSerializerOptions() {
				IgnoreNullValues = true,
				PropertyNameCaseInsensitive = true,
				PropertyNamingPolicy = null,
			};
			var input = JsonSerializer.Deserialize<Input>(json, options);
			Assert.Equal("filepath.Abs", input.Api);
			Assert.Equal(".", input.Path);
		}
	}
}
