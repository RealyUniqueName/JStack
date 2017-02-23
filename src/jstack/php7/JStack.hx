package jstack.php7;

import php.*;
import php.Global.*;
import haxe.CallStack;
import sourcemap.SourcePos;

using StringTools;

/**
 * Handles source map
 */
class JStack {
    static var sourceMaps = new Map<String,SourceMap>();

    /**
     * Invokes initialization.
     */
    static public inline function onReady (callback:Void->Void) : Void
    {
        init();
        callback();
    }

    /**
     * Overwrite this method to handle uncaught exceptions manually.
     * Any returned value will be written to stderr.
     * @param e - Uncaught exception.
     */
    @:access(haxe.CallStack)
    static public dynamic function uncaughtExceptionHandler (e:Throwable) : String {
        var stack = CallStack.makeStack(getNativeStack(e));
        var error = e.getMessage() + CallStack.toString(stack.map(mapStackItem)) + '\n';
        return error;
    }

    /**
     * Initialization
     */
    static function init () {
        var userDefined = set_exception_handler(_uncaughtExceptionHandler);
        //we have a user-defined handler, don't overwrite it.
        if (userDefined != null) set_exception_handler(userDefined);
    }

    /**
     * Actual handler passed to `set_exception_handler`
     * @param e -
     */
    static function _uncaughtExceptionHandler (e:Throwable) {
        var error = uncaughtExceptionHandler(e);
        Sys.stderr().writeString(error);
    }

    /**
     * Replaces file name and line number in stack items.
     * @param item -
     */
    static inline function mapStackItem (item:StackItem) : StackItem {
        switch (item) {
            case FilePos(symbol, file, line):
                var map = getSourceMap(file);
                if (map == null) {
                    return item;
                } else {
                    var pos = map.originalPositionFor(line);
                    return FilePos(symbol, pos.source, pos.originalLine);
                }
            case _:
                return item;
        }
    }

    /**
     * Handles source map parsers for each file.
     * @param file - A name of a generated php file.
     */
    static inline function getSourceMap (file:String) : Null<SourceMap> {
        var map = sourceMaps.get(file);
        if (map == null && !sourceMaps.exists(file)) {
            try {
                map = new SourceMap(file_get_contents('$file.map'));
            } catch(e:Dynamic) {}
            sourceMaps.set(file, map);
        }
        return map;
    }

    static function getNativeStack (e:Throwable) : NativeIndexedArray<NativeAssocArray<Dynamic>> {
        var stack = e.getTrace();

        var thrownAt = new NativeAssocArray<Dynamic>();
        thrownAt['function'] = '';
        thrownAt['line'] = e.getLine();
        thrownAt['file'] = e.getFile();
        thrownAt['class'] = '';
        thrownAt['args'] = new NativeArray();
        array_unshift(stack, thrownAt);

        return stack;
    }
}