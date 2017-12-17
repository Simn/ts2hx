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
	TsNamespace;
	TsStatic;
	TsPublic;
	TsPrivate;
	TsVar;
	TsConst;
	TsLet;
	TsTypeof;
	TsRequire;
	TsDefault;
	TsType;
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
	TStar;
	TAnd;
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