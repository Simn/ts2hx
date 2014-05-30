import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.macro.Context;

using StringTools;

class Test {
	static public function run(path:String) {
		function browse(dirPath) {
			var dir = FileSystem.readDirectory(dirPath);
			for (file in dir) {
				var path = Path.join([dirPath, file]);
				if (FileSystem.isDirectory(path)) {
					browse(path);
				} else if (file.endsWith(".hx")) {
					var old = Sys.getCwd();
					var moduleName = file.substr(0, -3);
					Sys.setCwd(dirPath);
					var proc = new sys.io.Process("haxe", [moduleName]);
					Sys.setCwd(old);
					var exit = proc.exitCode();
					if (exit != 0) {
						var result = proc.stderr.readAll().toString();
						result = result.replace(file, path);
						Sys.stderr().writeString(result);
					}
				}
			}
		}
		browse(path);
	}
}