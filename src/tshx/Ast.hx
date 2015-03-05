package tshx;

// Types

typedef TsTypeParameters = Array<TsTypeParameter>;

typedef TsTypeParameter = {
	name: String,
	constraint: Null<TsType>
}

typedef TsIdentifierPath = Array<String>;

enum TsPredefinedType {
	TAny;
	TNumber;
	TBoolean;
	TString;
	TVoid;
}

typedef TsTypeReference = {
	path: TsIdentifierPath,
	params: Array<TsType>
}

typedef TsArgument = {
	name: String,
	optional: Bool,
	type: Null<TsType>
}

enum TsPropertyName {
	TIdentifier(s:String);
	TStringLiteral(s:String);
	TNumericLiteral(s:String);
}

typedef TsPropertySignature = {
	name: TsPropertyName,
	optional: Bool,
	type: Null<TsType>
}

typedef TsCallSignature = {
	params: TsTypeParameters,
	arguments: Array<TsArgument>,
	type: Null<TsType>
}

typedef TsIndexSignature = {
	name: String,
	type: TsType
}

typedef TsMethodSignature = {
	name: TsPropertyName,
	optional: Bool,
	callSignature: TsCallSignature
}

enum TsTypeMember {
	TProperty(sig:TsPropertySignature);
	TCall(sig:TsCallSignature);
	TConstruct(sig:TsCallSignature);
	TIndex(sig:TsIndexSignature);
	TMethod(sig:TsMethodSignature);
}

typedef TsObjectType = Array<TsTypeMember>;

typedef TsFunctionType = {
	params: TsTypeParameters,
	arguments: Array<TsArgument>,
	ret: TsType
}

enum TsTypeLiteral {
	TObject(t:TsObjectType);
	TArray(t:TsType);
	TFunction(t:TsFunctionType);
	TConstructor(t:TsFunctionType);
}

enum TsType {
	TPredefined(t:TsPredefinedType);
	TTypeReference(t:TsTypeReference);
	TTypeQuery(path:TsIdentifierPath);
	TTypeLiteral(t:TsTypeLiteral);
	TRestArgument(t:TsType);
	TTypeChoice(t1:TsType, t2:TsType);
	TTuple(tl:Array<TsType>);
}

// Declarations

typedef TsInterface = {
	name: String,
	params: TsTypeParameters,
	parents: Array<TsTypeReference>,
	t: TsObjectType
}

typedef TsVariable = {
	name: String,
	type: Null<TsType>,
}

typedef TsFunction = {
	name: String,
	callSignature: TsCallSignature
}

typedef TsClass = {
	name: String,
	params: TsTypeParameters,
	parentClass: Null<TsTypeReference>,
	interfaces: Array<TsTypeReference>,
	t: TsObjectType
}

typedef TsEnum = {
	name: String,
	constructors: Array<TsEnumCtor>
}

typedef TsModule = {
	path: TsIdentifierPath,
	elements: Array<TsDeclaration>
}

typedef TsEnumCtor = {
	name: TsPropertyName,
	value: Null<String>
}

typedef TsImportDeclaration = {
	name: String,
	entityName: TsIdentifierPath
}

typedef TsExternalImportDeclaration = {
	name: String,
	moduleReference: String
}

enum TsDeclaration {
	DVariable(v:TsVariable);
	DFunction(f:TsFunction);
	DClass(c:TsClass);
	DEnum(en:TsEnum);
	DInterface(i:TsInterface);
	DModule(m:TsModule);
	DExternalModule(m:TsModule);
	DImport(i:TsImportDeclaration);
	DExternalImport(i:TsExternalImportDeclaration);
	DExportAssignment(s:String);
}