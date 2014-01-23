ts2hx
=====

Typescript external definitions to haxe converter. I use it like this:
	
```
neko ts2hx.n "C:\\Github\\DefinitelyTyped" --recursive --in "\.d\.ts$"
```

You can also try

```
neko ts2hx.n --help
```

Requires https://github.com/Simn/hxargs and https://github.com/Simn/hxparse