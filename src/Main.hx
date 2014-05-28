import tshx.Lexer;
import tshx.Parser;
import tshx.Ast;

using StringTools;

class Config {
	public var outDir = "out";
	public var inPaths = [];
	public var recursive = false;
	public var inclusionFilters:Array<EReg> = [];

	public function new() { }
}

class Main {
	static function main() {
		var config = new Config();
		var printHelp = false;
		var handler = hxargs.Args.generate([
			@doc("Set output directory (default: out)")
			"-o" => function(dir:String) {
				config.outDir = dir;
			},
			@doc("Browse directories recursively for .ts files")
			"--recursive" => function() {
				config.recursive = true;
			},
			@doc("Only convert files which match this regular expression")
			"--in" => function(ereg:String) {
				config.inclusionFilters.push(new EReg(ereg, ""));
			},
			"--help" => function() {
				printHelp = true;
			},
			_ => function(dir:String) {
				if (dir.charAt(0) == "-") {
					Sys.println("Unknown command: " + dir);
					Sys.exit(0);
				}
				config.inPaths.push(dir);
			}
		]);
		var args = Sys.args();
		handler.parse(args);
		if (printHelp) {
			Sys.println("Usage: ts2hx [options] <input path>");
			Sys.println(handler.getDoc());
			Sys.exit(0);
		}
		if (config.inPaths.length == 0) {
			config.inPaths = ["."];
		}
		if (config.inclusionFilters.length == 0) {
			config.inclusionFilters.push(~/\.d\.ts$/);
		}
		if (!sys.FileSystem.exists(config.outDir)) {
			sys.FileSystem.createDirectory(config.outDir);
		}
		run(config);
	}

	static function run(config:Config) {
		function convert(content:String, filePath:String) {
			var input = byte.ByteData.ofString(content);
			var parser = new Parser(input, filePath);
			var decls = try {
				parser.parse();
			} catch(e:hxparse.NoMatch<Dynamic>) {
				throw e.pos.format(input) + ": NoMatch " +e.token.def;
			} catch(e:hxparse.Unexpected<Dynamic>) {
				throw e.pos.format(input) + ": Unexpected " + e.token.def;
			} catch(e:hxparse.UnexpectedChar) {
				throw e.pos.format(input) + ": Unexpected `" + e.char;
			}
			var converter = new tshx.Converter();
			converter.convert(decls);
			var outDir = config.outDir + "/" + filePath;
			if (!sys.FileSystem.exists(outDir)) {
				sys.FileSystem.createDirectory(outDir);
			}
			var printer = new haxe.macro.Printer();
			for (k in converter.modules.keys()) {
				var outPath = outDir + "/" + k.replace("/", "_") + ".hx";
				var buf = new StringBuf();
				for (t in converter.modules[k].types) {
					var s = printer.printTypeDefinition(t);
					buf.add(s);
					buf.add("\n");
				}
				if (buf.length > 0) {
					sys.io.File.saveContent(outPath, buf.toString());
					trace('Written $outPath');
				}
			}
		}
		function loop(base:String, entry:String, level:Int) {
			var path = base + entry;
			if (sys.FileSystem.isDirectory(path)) {
				if (!config.recursive && level > 0) {
					return;
				}
				var dir = sys.FileSystem.readDirectory(path);
				for (entry2 in dir) {
					loop(path + "/", entry2, level + 1);
				}
			} else {
				if(!isFiltered(config, path)) {
					var content = sys.io.File.getContent(path);
					convert(content, entry.substr(0, -5));
				}
			}
		}
		for (path in config.inPaths) {
			if (!sys.FileSystem.exists(path)) {
				Sys.println("Could not open " +path);
			} else if (sys.FileSystem.isDirectory(path)) {
				loop(path, "", 0);
			} else {
				loop("./", path, 0);
			}
		}
	}

	static function isFiltered(config:Config, path:String) {
		if (config.inclusionFilters.length > 0) {
			for (ereg in config.inclusionFilters) {
				if (ereg.match(path)) {
					return false;
				}
			}
			return true;
		}
		return false;
	}
}