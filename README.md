# JStack

This library automatically transforms `haxe.CallStack.callStack()` and `haxe.CallStack.exceptionStack()` results to make them point at Haxe sources instead of generated js file.
The only supported target is `js`.

Works only in debug mode on js target. Does not affect your app if compiled without `-debug` flag or to some other target.

In debug mode Haxe generates a source map, which is utilized by JStack using (source-map library)[https://github.com/mozilla/source-map].

## Installation
```haxe
haxelib install jstack
```

## Usage
In most cases all you need to do is just add JStack to compilation with `-lib jstack` compiler flag.

### Accessing call stack before exiting `static main()`
Source map loading is an asynchronous process, so if you need to access call stack right after your app started, you have to wait until source map is loaded:
```haxe
jstack.JStack.onReady(function () {
    //app start here
});
```