import tshx.Lexer;
import tshx.Parser;
import tshx.Ast;

using StringTools;

private class Config {
	public var outDir = "out";
	public var inPaths = [];
	public var recursive = false;
	public var ignoreErrors = false;
	public var inclusionFilters:Array<EReg> = [];

	public function new() { }
}

class Main {
	/**
		This is the entry point to Ts2Hx. It parses the command line arguments
		and then invokes the `run` method with the resulting configuration.
	**/
	static function main() {
		var config = new Config();
		var printHelp = false;
		var handler = hxargs.Args.generate([
			@doc("Set output directory (default: out)")
			"-o" => function(dir:String) {
				config.outDir = dir;
			},
			@doc("Browse input paths recursively")
			"--recursive" => function() {
				config.recursive = true;
			},
			@doc("Ignore conversion errors")
			"--ignore-errors" => function() {
				config.ignoreErrors = true;
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

	/**
		Executes Ts2Hx with the given `config`.

		This method traverses the input and finds all relevant files, which are
		then read and passed to `convert`.
	**/
	static function run(config:Config) {
		function loop(base:String, entry:String, level:Int, errors) {
			var path = base + entry;
			if (sys.FileSystem.isDirectory(path)) {
				if (!config.recursive && level > 0) {
					return;
				}
				var dir = sys.FileSystem.readDirectory(path);
				for (entry2 in dir) {
					loop(path + "/", entry2, level + 1, errors);
				}
			} else {
				if(!isFiltered(config, path)) {
					var content = sys.io.File.getContent(path);
					var relPath = config.inPaths.length == 1 ? path.substr(config.inPaths[0].length) : path;
					var convert = convert.bind(config, content, entry.substr(0, -5), relPath);
					if (config.ignoreErrors) {
						try {
							convert();
						} catch (e:Dynamic) {
							errors.push({ path : path, error : e });
							Sys.println("Error converting file " + path + ": " + Std.string(e));
						}
					} else {
						convert();
					}
				}
			}
		}
		var errors = [];
		for (path in config.inPaths) {
			if (!sys.FileSystem.exists(path)) {
				Sys.println("Could not open " +path);
			} else if (sys.FileSystem.isDirectory(path)) {
				loop(path, "", 0, errors);
			} else {
				loop("./", path, 0, errors);
			}
		}
		if (config.ignoreErrors && errors.length > 0) {
			Sys.println("\nError Report:\n");
			for (e in errors) {
				Sys.println('File "${e.path}": ${Std.string(e.error)}');
			}
		}
	}

	/**
		Converts the Typescript code `content` to Haxe code.

		This is a 3-step process:

			1. The input code is parsed into the structures defined in `Ast`.
			2. The structures are converted to Haxe structures by `Converter`.
			3. The Haxe structures are printed using `haxe.macro.Printer`.
	**/
	static function convert(config:Config, content:String, name:String, filePath:String) {
		// Step 1: Parse the code
		var input = byte.ByteData.ofString(content);
		var parser = new Parser(input, name, filePath);
		var decls = hxparse.Utils.catchErrors(input, function() {
			return parser.parse();
		});
		// Step 2: Convert the Typescript declarations to Haxe declarations.
		var converter = new tshx.Converter();
		converter.convert(decls);
		// Make sure the output directory exists.
		var outDir = config.outDir + "/" + name;
		if (!sys.FileSystem.exists(outDir)) {
			sys.FileSystem.createDirectory(outDir);
		}
		// Step 3: Use haxe.macro.Printer to print the Haxe declarations.
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
				Sys.println('Written $outPath');
			}
		}
	}

	/**
		Tells if `path` is filtered according to the filter rules in `config`.
	**/
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