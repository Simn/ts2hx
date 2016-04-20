package tshx;

import tshx.Token;
import tshx.Ast;

class TsParserError extends hxparse.ParserError {
	public var message:String;

	public function new(message:String, pos) {
		super(pos);
		this.message = message;
	}

	override function toString() {
		return message;
	}
}

class Parser extends hxparse.Parser<hxparse.LexerTokenSource<TsToken>, TsToken> implements hxparse.ParserBuilder {

	var moduleName:String;

	public function new(input:byte.ByteData, sourceName:String) {
		moduleName = sourceName;
		super(new hxparse.LexerTokenSource(new tshx.Lexer(input, sourceName), tshx.Lexer.tok));
	}

	public function parse() {
		var m = {
			path: [moduleName],
			elements: []
		}
		while(true) {
			switch stream {
				case [d = declaration()]:
					m.elements.push(d);
				case [{def:TEof}]:
					break;
			}
		}
		return m;
	}

	// Declarations

	function declaration() {
		var modifier = modifier(); // TODO: do something with these?
		var r = switch stream {
			case [{def: TKeyword(TsVar | TsConst | TsLet)}, i = identifier(), t = popt(typeAnnotation)]:
				topt(TSemicolon);
				DVariable({
					name: i,
					type: t
				});
			case [{def: TKeyword(TsFunction)}, i = identifier(), call = callSignature()]:
				DFunction({
					name: i,
					callSignature: call
				});
			case [i = Interface()]:
				DInterface(i);
			case [c = Class()]:
				DClass(c);
			case [en = Enum()]:
				DEnum(en);
			case [t = Typedef()]:
				DTypedef(t);
			case [{def: TKeyword(TsModule) | TKeyword(TsNamespace)}]:
				switch stream {
					case [path = identifierPath(), {def: TLBrace}, fl = plist(declaration), {def: TRBrace}]:
						DModule({
							path: path,
							elements: fl
						});
					case [{def: TString(s)}, {def: TLBrace}, fl = plist(declaration), {def: TRBrace}]:
						DExternalModule({
							path: [s],
							elements: fl
						});
				}
			case [{def: TKeyword(TsImport)}, i = identifier(), {def: TAssign}]:
				switch stream {
					case [{def: TKeyword(TsRequire)}, {def: TLPar}, {def: TString(s)}, {def: TRPar}, {def: TSemicolon}]:
						DExternalImport({
							name: i,
							moduleReference: s
						});
					case [path = identifierPath()]:
						DImport({
							name: i,
							entityName: path
						});
				}
			case [{def:TKeyword(TsExport)}]:
				switch stream {
					case [{def: TAssign}, i = identifier(), _ = topt(TSemicolon)]: DExportAssignment(i);
					case [d = declaration()]: d;
				}
			case [{def: TKeyword(TsDeclare)}]:
				declaration();
		}
		topt(TSemicolon);
		return r;
	}

	function modifier() {
		return switch stream {
			case [{def: TIdent("const")}]: ["const"];
			case _: [];
		}
	}

	// Interface

	function Interface() {
		return switch stream {
			case [{def: TKeyword(TsInterface)}, i = identifier(), tl = popt(typeParameters), ext = popt(interfaceExtendsClause), t = objectType(false)]:
				{
					name: i,
					params: tl == null ? [] : tl,
					parents: ext == null ? [] : ext,
					t: t
				}
		}
	}

	function interfaceExtendsClause() {
		return switch stream {
			case [{def: TKeyword(TsExtends)}, tl = psep(TComma, typeReference)]:
				tl;
		}
	}

	// Class

	function Class() {
		return switch stream {
			case [{def: TKeyword(TsClass)}, i = identifier(), tl = popt(typeParameters), h = classHeritage(), t = objectType(true)]:
				{
					name: i,
					params: tl == null ? [] : tl,
					parentClass: h.ext,
					interfaces: h.impl == null ? [] : h.impl,
					t: t
				}
		}
	}

	function classHeritage() {
		var ext = popt(classExtendsClause);
		var impl = popt(implementsClause);
		return {
			ext: ext,
			impl: impl
		}
	}

	function classExtendsClause() {
		return switch stream {
			case [{def: TKeyword(TsExtends)}, t = typeReference()]:
				t;
		}
	}

	function implementsClause() {
		return switch stream {
			case [{def: TKeyword(TsImplements)}, tl = psep(TComma, typeReference)]:
				tl;
		}
	}

	// Enum

	function Enum() {
		return switch stream {
			case [{def: TKeyword(TsEnum)}, i = identifier(), {def: TLBrace}, ctors = plist(enumCtor), {def: TRBrace}]:
				{
					name: i,
					constructors: ctors
				}
		}
	}

	function enumCtor() {
		return switch stream {
			case [n = propertyName(), v = popt(assignmentExpression)]:
				topt(TComma);
				{
					name: n,
					value: v
				}
		}
	}

	function assignmentExpression() {
		return switch stream {
			case [{def: TAssign}]:
				switch stream {
					case [{def: TNumber(s)}]: s;
				}
		}
	}

	// Typedef

	function Typedef() {
		return switch stream {
			case [{def: TIdent("type")}, i = identifier(), {def: TAssign}, tl = psep(TPipe, type)]:
				{
					name: i,
					types: tl
				}
		}
	}

	// Type Parameters

	function typeParameters() {
		return switch stream {
			case [{def: TLt}, tl = psep(TComma, typeParameter), {def: TGt}]:
				tl;
		}
	}

	function typeParameter() {
		return switch stream {
			case [i = identifier(), constraint = popt(constraint)]:
				{
					name: i,
					constraint: constraint
				}
		}
	}

	function constraint() {
		return switch stream {
			case [{def: TKeyword(TsExtends)}, t = type()]:
				t;
		}
	}

	// Types

	function type() {
		return typeNext(switch stream {
			case [{def: TIdent("any")}]: TPredefined(TAny);
			case [{def: TIdent("number")}]: TPredefined(TNumber);
			case [{def: TIdent("boolean" | "bool")}]: TPredefined(TBoolean);
			case [{def: TIdent("string")}]: TPredefined(TString);
			case [{def: TIdent("void")}]: TPredefined(TVoid);
			case [{def: TKeyword(TsTypeof)}, path = identifierPath()]: TTypeQuery(path);
			case [{def: TKeyword(TsNew)}, f = functionType()]: TTypeLiteral(TConstructor(f));
			case [r = typeReference()]: TTypeReference(r);
			case [o = objectType(false)]: TTypeLiteral(TObject(o));
			case [{def: TLPar}]: parenthesisType();
			case [{def: TString(s)}]: TTypeReference({ path: [s], params: []});
			case [{def: TLBrack}, types = psep(TComma, type), {def: TRBrack}]: TTuple(types);
			case _:
				if (peek(0).def == TLt) {
					TTypeLiteral(TFunction(functionType()));
				} else {
					throw noMatch();
				}
		});
	}

	function typeNext(t) {
		return switch stream {
			case [{def:TLBrack}, {def:TRBrack}]: typeNext(TTypeLiteral(TArray(t)));
			case [{def:TPipe}, t2 = type()]: typeNext(TTypeChoice(t, t2));
			case _: t;
		}
	}

	function typeArguments() {
		return switch stream {
			case [{def: TLt}, tl = psep(TComma, type), {def: TGt}]:
				tl;
		}
	}

	function typeReference() {
		return switch stream {
			case [path = identifierPath(), tl = popt(typeArguments)]:
				{
					path: path,
					params: tl == null ? [] : tl
				}
		}
	}

	function objectType(isClass) {
		return switch stream {
			case [{def: TLBrace}, fl = plist(typeMember.bind(isClass)), {def:TRBrace}]:
				fl;
		}
	}

	function typeMember(isClass) {
		var isPublic = publicOrPrivate();
		var isStatic = isClass ? Static() : false;
		var r = switch stream {
			case [n = propertyName()]:
				typeMemberProperty(isPublic, isStatic, n);
			case [call = callSignature()]:
				TCall(call);
			case [{def: TKeyword(TsNew)}, call = callSignature()]:
				TConstruct(call);
			case [{def: TLBrack}, i = identifier(), {def: TColon}, s = identifier(), {def:TRBrack}, t = typeAnnotation()]:
				TIndex({
					name: i,
					type: t
				});
			case _:
				if (peek(0).def == TColon) {
					// this is really, really weird, but apparently you can have
					// members named static, private or public.
					if (isStatic) {
						typeMemberProperty(isPublic, false, TIdentifier("static"));
					} else if (isPublic) {
						typeMemberProperty(false, isStatic, TIdentifier("public"));
					} else {
						typeMemberProperty(false, isStatic, TIdentifier("private"));
					}
				} else {
					throw noMatch();
				}
		}
		topt(TSemicolon);
		return r;
	}

	function typeMemberProperty(isPublic:Bool, isStatic:Bool, n:TsPropertyName) {
		var opt = switch stream {
			case [{def: TQuestion}]: true;
			case _: false;
		}
		return switch stream {
			case [call = callSignature()]:
				TMethod({
					name: n,
					optional: opt,
					isStatic: isStatic,
					callSignature: call
				});
			case _:
				var t = popt(typeAnnotation);
				TProperty({
					name: n,
					optional: opt,
					isStatic: isStatic,
					type: t
				});
		}
	}

	function publicOrPrivate() {
		return switch stream {
			case [{def: TKeyword(TsPublic)}]: true;
			case [{def: TKeyword(TsPrivate)}]: false;
			case _: true;
		}
	}

	function Static() {
		return switch stream {
			case [{def: TKeyword(TsStatic)}]: true;
			case _: false;
		}
	}

	function functionType() {
		var tl = popt(typeParameters);
		return switch stream {
			case [{def: TLPar}, args = psep(TComma, argument), {def: TRPar}, {def: TArrow}, t = type()]:
				{
					params: tl == null ? [] : tl,
					arguments: args,
					ret: t
				}
		}
	}

	function isFunctionType() {
		return switch (peek(0)) {
			case {def: TIdent(_) | TKeyword(_)}:
				switch (peek(1)) {
					case {def: TQuestion | TColon | TRPar | TComma}:
						true;
					case _:
						false;
				}
			case {def: TEllipsis}:
				true;
			case {def: TRPar}:
				true; // not sure about this one
			case {def: TLt}:
				true;
			case _:
				false;
		}
	}

	function parenthesisType() {
		if (isFunctionType()) {
			return switch stream {
				case [args = psep(TComma, argument), {def: TRPar}, {def: TArrow}, t = type()]:
					TTypeLiteral(TFunction({
						params: [],
						arguments: args,
						ret: t
					}));
				case _:
					unexpected();
			}
		} else {
			return switch stream {
				case [t = type(), {def: TRPar}]:
					typeNext(t);
			}
		}
	}

	function typeAnnotation() {
		return switch stream {
			case [{def: TColon}, t = type()]:
				t;
		}
	}

	// Function

	function callSignature() {
		var tl = popt(typeParameters);
		return switch stream {
			case [{def: TLPar}, args = psep(TComma, argument), {def:TRPar}, t = popt(typeAnnotation)]:
				{
					params: tl == null ? [] : tl,
					arguments: args,
					type: t
				}
		}
	}

	function argument() {
		return switch stream {
			case [i = identifier()]:
				var opt = switch stream {
					case [{def: TQuestion}]: true;
					case _: false;
				}
				var t = popt(typeAnnotation);
				{
					name: i,
					optional: opt,
					type: t,
				}
			case [{def: TEllipsis}, a = argument()]:
				var t = switch (a.type) {
					case null: TPredefined(TAny); // TODO: not sure here
					case TTypeLiteral(TArray(t)): t;
					case TTypeReference({path: ["Array"], params: [t]}): t;
					case t: throw new TsParserError("rest parameters should be arrays, found " + t, stream.curPos());
				}
				a.type = TRestArgument(t);
				a;
		}
	}

	// Identifier

	function identifier() {
		return switch stream {
			case [{def: TIdent(s)}]: s;
			case [{def:TKeyword(kwd)}]: kwd.getName().charAt(2).toLowerCase() + kwd.getName().substr(3);
		}
	}

	function identifierPath():TsIdentifierPath {
		return switch stream {
			case [i = identifier()]:
				switch stream {
					case [{def: TDot}]:
						var i2 = identifierPath();
						i2.unshift(i);
						i2;
					case _:
						[i];
				}
		}
	}

	function propertyName() {
		return switch stream {
			case [i = identifier()]:
				TIdentifier(i);
			case [{def: TString(s)}]:
				TStringLiteral(s);
			case [{def:TNumber(s)}]:
				TNumericLiteral(s);
		}
	}

	// Helper

	function topt(tdef:TsTokenDef) {
		return switch stream {
			case [{def:def} && def == tdef]: true;
			case _: false;
		}
	}

	function plist<T>(f:Void->T):Array<T> {
		var acc = [];
		try {
			while(true) {
				acc.push(f());
			}
		} catch(e:hxparse.NoMatch<Dynamic>) {}
		return acc;
	}

	function psep<T>(sep:TsTokenDef, f:Void->T):Array<T> {
		var acc = [];
		while(true) {
			try {
				acc.push(f());
				switch stream {
					case [{def:sep2} && sep2 == sep]:
				}
			} catch(e:hxparse.NoMatch<Dynamic>) {
				break;
			}
		}
		return acc;
	}

	function popt<T>(f:Void->T):Null<T> {
		return switch stream {
			case [v = f()]: v;
			case _: null;
		}
	}

	@:access(hxparse.Parser.peek)
	override function peek(n) {
		var r = if (n == 0)
			switch(super.peek(0)) {
				case {def:TComment(_)}:
					junk();
					peek(0);
				case t: t;
			}
		else
			super.peek(n);
		return r;
	}
}