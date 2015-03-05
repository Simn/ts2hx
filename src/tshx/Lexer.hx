package tshx;

import tshx.Token;

class Lexer extends hxparse.Lexer implements hxparse.RuleBuilder {
	static var buf:StringBuf;
	static public var keywords = @:mapping(2) TsKeyword;

	static inline function mk(def:TsTokenDef, lexer:hxparse.Lexer) return new TsToken(def, lexer.curPos());

	static var ident = "_*[a-zA-Z_\\$][a-zA-Z_0-9\\$]*|_+|_+[0-9][_a-zA-Z0-9]*";

	public static var tok = @:rule [
		"\\239\\187\\191" => lexer.token(tok),
		"\\(" => mk(TLPar, lexer),
		"\\)" => mk(TRPar, lexer),
		"{" => mk(TLBrace, lexer),
		"}" => mk(TRBrace, lexer),
		"," => mk(TComma, lexer),
		":" => mk(TColon, lexer),
		"[" => mk(TLBrack, lexer),
		"]" => mk(TRBrack, lexer),
		"<" => mk(TLt, lexer),
		">" => mk(TGt, lexer),
		";" => mk(TSemicolon, lexer),
		"=" => mk(TAssign, lexer),
		"=>" => mk(TArrow, lexer),
		"?" => mk(TQuestion, lexer),
		"|" => mk(TPipe, lexer),
		"\\." => mk(TDot, lexer),
		"\\.\\.\\." => mk(TEllipsis, lexer),
		"-?(([1-9][0-9]*)|0)(.[0-9]+)?([eE][\\+\\-]?[0-9]?)?" => mk(TNumber(lexer.current), lexer),
		'"' => {
			buf = new StringBuf();
			lexer.token(string);
			mk(TString(buf.toString()), lexer);
		},
		"'" => {
			buf = new StringBuf();
			lexer.token(string2);
			mk(TString(buf.toString()), lexer);
		},
		"//[^\n\r]*" => mk(TComment(lexer.current.substr(2)), lexer),
		'/\\*' => {
			buf = new StringBuf();
			var pmin = lexer.curPos();
			var pmax = try lexer.token(comment) catch (e:haxe.io.Eof) throw "Unclosed comment";
			mk(TComment(buf.toString()), lexer);
		},
		"[\r\n\t ]" => lexer.token(tok),
		ident => {
			var kwd = keywords.get(lexer.current);
			if (kwd != null)
				mk(TKeyword(kwd), lexer);
			else
				mk(TIdent(lexer.current), lexer);
		},
		"" => mk(TEof, lexer)
	];

	static var string = @:rule [
		"\\\\t" => {
			buf.addChar("\t".code);
			lexer.token(string);
		},
		"\\\\n" => {
			buf.addChar("\n".code);
			lexer.token(string);
		},
		"\\\\r" => {
			buf.addChar("\r".code);
			lexer.token(string);
		},
		'\\\\"' => {
			buf.addChar('"'.code);
			lexer.token(string);
		},
		"\\\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]" => {
			buf.add(String.fromCharCode(Std.parseInt("0x" +lexer.current.substr(2))));
			lexer.token(string);
		},
		'"' => {
			lexer.curPos().pmax;
		},
		'[^"]+' => {
			buf.add(lexer.current);
			lexer.token(string);
		},
	];

	public static var string2 = @:rule [
		"\\\\\\\\" => {
			buf.add("\\");
			lexer.token(string2);
		},
		"\\\\b" =>  {
			buf.addChar(8);
			lexer.token(string2);
		},
		"\\\\n" =>  {
			buf.add("\n");
			lexer.token(string2);
		},
		"\\\\r" => {
			buf.add("\r");
			lexer.token(string2);
		},
		"\\\\t" => {
			buf.add("\t");
			lexer.token(string2);
		},
		'\\\\\'' => {
			buf.add('"');
			lexer.token(string2);
		},
		"'" => lexer.curPos().pmax,
		'[^\\\\\']+' => {
			buf.add(lexer.current);
			lexer.token(string2);
		}
	];

	public static var comment = @:rule [
		"*/" => lexer.curPos().pmax,
		"*" => {
			buf.add("*");
			lexer.token(comment);
		},
		"[^\\*]+" => {
			buf.add(lexer.current);
			lexer.token(comment);
		}
	];
}