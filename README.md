# JStack

This library automatically transforms `haxe.CallStack.callStack()`, `haxe.CallStack.exceptionStack()` and uncaught exceptions where possible to make them point at Haxe sources instead of generated js or php files.
The only supported targets are `js` and `php7` (as of 2017-02-24 you need latest development version of Haxe for php7 support).

Works only in debug mode or when `-D JSTACK_FORCE`.
Does not affect your app if compiled without `-debug` and `-D JSTACK_FORCE` flags or to unsupported target.

In debug mode Haxe generates a source map, which is utilized by JStack using [source-map library](https://github.com/mozilla/source-map) (bundled with JStack and embded automatically)

## Installation
```haxe
haxelib install jstack
```

## Usage
Just add JStack to compilation with `-lib jstack` compiler flag.