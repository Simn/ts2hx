ts2hx
=====

**Don't use this, it is unmaintained and outdated. Use https://github.com/haxiomic/dts2hx instead!**

[![Build Status](https://travis-ci.org/Simn/ts2hx.svg?branch=master)](https://travis-ci.org/Simn/ts2hx)

Typescript external definitions to haxe converter. I use it like this:

```
neko ts2hx.n "C:\\Github\\DefinitelyTyped" --recursive --in "\.d\.ts$"
```

You can also try

```
neko ts2hx.n --help
```

Requires https://github.com/Simn/hxargs and https://github.com/Simn/hxparse
