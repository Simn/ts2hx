package tshx;

import tshx.Ast;
import haxe.macro.Expr;

typedef HaxeModule = {
	types: Array<TypeDefinition>
}

class Converter {

	static var nullPos = { min:0, max:0, file:"" };
	static var tDynamic = TPath({ pack: [], name: "Dynamic", sub: null, params: [] });
	static var tInt = { pack: [], name: "Int", sub: null, params: [] };

	public var modules(default, null):Map<String, HaxeModule>;
	var currentModule:HaxeModule;

	public function new() {
		modules = new Map();
	}

	public function convert(module:TsModule) {
		convertDecl(DModule(module));
	}

	function convertDecl(d:TsDeclaration) {
		switch(d) {
			case DModule(m):
				convertModule(m);
			case DInterface(i):
				currentModule.types.push(convertInterface(i));
			case DClass(c):
				currentModule.types.push(convertClass(c));
			case DEnum(en):
				currentModule.types.push(convertEnum(en));
			case DFunction(_) | DVariable(_):
				// TODO: we need some convention for that
			case DExternalModule(_) | DImport(_) | DExportAssignment(_):
				// TODO: do we need these?
		}
	}

	function convertFields(fl:Array<TsTypeMember>) {
		var fields = [];
		var fieldMap = new Map();
		for (mem in fl) {
			var field = convertMember(mem);
			if (field != null) {
				if (fieldMap.exists(field.name)) {
					var field2 = fieldMap[field.name];
					var f = switch(field.kind) {
						case FFun(f):
							f;
						case _:
							// TODO: this probably means we have a member + static property with the same name
							continue;
					}
					f.expr = { expr: EBlock([]), pos: nullPos };
					field2.meta.push({name: ":overload", params: [{expr:EFunction(null, f), pos: nullPos}], pos: nullPos});
				} else {
					fields.push(field);
					fieldMap[field.name] = field;
				}
			}
		}
		return fields;
	}

	function convertModule(m:TsModule) {
		var name = pathToString(m.path);
		if (!modules.exists(name)) {
			modules[name] = {
				types: []
			}
		}
		var old = currentModule;
		currentModule = modules[name];
		for (decl in m.elements) {
			convertDecl(decl);
		}
	}

	function convertInterface(i:TsInterface) {
		var fields = convertFields(i.t);
		var parents = i.parents.map(convertTypeReference);
		var kind = parents.length == 0 ? TAnonymous(fields) : TExtend(parents, fields);
		var td = {
			pack: [],
			name: i.name,
			pos: nullPos,
			meta: [],
			params: i.params.map(convertTypeParameter),
			isExtern: false,
			kind: TDAlias(kind),
			fields: []
		}
		return td;
	}

	function convertClass(c:TsClass) {
		var fields = convertFields(c.t);
		var interfaces = c.interfaces.map(convertTypeReference);
		// TODO: can't implement typedefs, I guess we can rely on structural subtyping
		interfaces = [];
		var td = {
			pack: [],
			name: c.name,
			pos: nullPos,
			meta: [],
			params: c.params.map(convertTypeParameter),
			isExtern: true,
			kind: TDClass(c.parentClass == null ? null : convertTypeReference(c.parentClass), interfaces),
			fields: fields
		}
		return td;
	}

	function convertEnum(en:TsEnum) {
		var i = 0;
		var fields = en.constructors.map(function(ctor) {
			if (ctor.value != null) {
				// TODO: I guess exported enums should not have int values
				i = Std.parseInt(ctor.value);
			}
			return {
				name: convertPropertyName(ctor.name),
				kind: FVar(null, { expr: EConst(CInt("" +i++)), pos: nullPos }),
				doc: null,
				meta: [],
				access: [APublic],
				pos: nullPos
			}
		});
		var td = {
			pack: [],
			name: en.name,
			pos: nullPos,
			meta: [{name: ":enum", params: [], pos: nullPos}],
			params: [],
			isExtern: false,
			kind: TDAbstract(TPath(tInt)),
			fields: fields
		}
		return td;
	}

	function convertMember(mem:TsTypeMember) {
		var o = switch(mem) {
			case TProperty(sig):
				var kind = FVar(sig.type == null ? tDynamic : convertType(sig.type));
				{ kind: kind, name: sig.name, opt: sig.optional };
			case TMethod(sig):
				var kind = FFun({
					args: sig.callSignature.arguments.map(convertArgument),
					ret: sig.callSignature.type == null ? tDynamic : convertType(sig.callSignature.type),
					expr: null,
					params: sig.callSignature.params.map(convertTypeParameter)
				});
				{ kind: kind, name: sig.name, opt: sig.optional };
			case TCall(_) | TConstruct(_) | TIndex(_):
				return null;
		}
		return {
			name: convertPropertyName(o.name),
			kind: o.kind,
			doc: null,
			meta: o.opt ? [{name: ":optional", params: [], pos: nullPos}] : [],
			access: [APublic],
			pos: nullPos
		}
	}

	function convertArgument(arg:TsArgument) {
		return {
			name: arg.name,
			opt: arg.optional,
			type: arg.type == null ? tDynamic : convertType(arg.type),
			value: null
		}
	}

	function convertTypeParameter(tp:TsTypeParameter) {
		return {
			name: tp.name,
			constraints: tp.constraint == null ? [] : [convertType(tp.constraint)],
			params: []
		}
	}

	function convertType(t:TsType):ComplexType {
		return switch(t) {
			case TPredefined(t):
				TPath(switch(t) {
					case TAny: { name: "Dynamic", pack: [], params: [], sub: null };
					case TNumber: { name: "Float", pack: [], params: [], sub: null };
					case TBoolean: { name: "Bool", pack: [], params: [], sub: null };
					case TString: { name: "String", pack: [], params: [], sub: null };
					case TVoid: { name: "Void", pack: [], params: [], sub: null };
				});
			case TTypeReference(t):
				TPath(convertTypeReference(t));
			case TTypeQuery(path):
				// TODO
				tDynamic;
			case TTypeLiteral(t):
				switch(t) {
					case TObject(o):
						var fields:Array<Field> = convertFields(o);
						TAnonymous(fields.filter(function(v) return v != null));
					case TArray(t):
						TPath({ name: "Array", pack: [], params: [TPType(convertType(t))], sub: null});
					case TFunction(f):
						var args = f.arguments.map(function(arg) {
							var t = arg.type == null ? tDynamic : convertType(arg.type);
							return arg.optional ? TOptional(t) : t;
						});
						TFunction(args, convertType(f.ret));
					case TConstructor(_):
						// TODO
						tDynamic;
				}
		}
	}

	function convertTypeReference(tref:TsTypeReference) {
		var tPath = {
			name: tref.path[tref.path.length - 1],
			pack: tref.path.slice(0, -1),
			params: tref.params.map(function(t) return TPType(convertType(t))),
			sub: null
		};
		switch [tPath.name, tPath.pack] {
			case ["Object", []]:
				tPath.name = "Dynamic";
			case _:
		}
		return tPath;
	}

	function convertPropertyName(pn:TsPropertyName) {
		return switch(pn) {
			case TIdentifier(s): s;
			case TStringLiteral(s): s;
			case TNumericLiteral(s): "_" + s;
		}
	}

	function pathToString(p:TsIdentifierPath) {
		return p.join(".");
	}
}