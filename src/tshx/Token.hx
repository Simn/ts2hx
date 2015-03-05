package tshx;

enum TsKeyword {
	TsClass;
	TsConstructor;
	TsDeclare;
	TsEnum;
	TsNew;
	TsImport;
	TsExport;
	TsExtends;
	TsFunction;
	TsImplements;
	TsInterface;
	TsModule;
	TsStatic;
	TsPublic;
	TsPrivate;
	TsVar;
	TsTypeof;
	TsRequire;
}

enum TsTokenDef {
	TLPar;
	TRPar;
	TLBrack;
	TRBrack;
	TLBrace;
	TRBrace;
	TLt;
	TGt;
	TColon;
	TSemicolon;
	TComma;
	TEquals;
	TAssign;
	TArrow;
	TQuestion;
	TEllipsis;
	TDot;
	TPipe;
	TKeyword(kwd:TsKeyword);
	TIdent(s:String);
	TString(s:String);
	TNumber(s:String);
	TComment(s:String);
	TEof;
}

class TsToken {
	public var def: TsTokenDef;
	public var pos: hxparse.Position;

	public function new(tok, pos) {
		this.def = tok;
		this.pos = pos;
	}
}