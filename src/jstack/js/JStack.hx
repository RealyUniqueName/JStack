package jstack.js;

import haxe.CallStack;
import sourcemap.SourcePos;
import js.Error;
import haxe.io.Path;
import js.Browser;
import haxe.Http;

/**
 * Handles source map
 */
class JStack {

    /** Create instance just to invoke `inject()` */
    static var instance = new JStack();
    /** Source map instance */
    static var mapper : SourceMap;
    /** User-defined callback which will be invoked when sourceMap is loaded */
    static var onReadyCallback : Void->Void;

    /** Native stack lines like: at /home/alex/Work/HaXe/jstack/build/js/test.js:729:22 */
    static var stackFile = ~/^at (.+?js):([0-9]+):([0-9]+)$/;
    /** Native stack lines like: at Object.Lab.level4 (/home/alex/Work/HaXe/jstack/build/js/test.js:70:9) */
    static var stackFunctionFile = ~/^at (.+?) \((.+?js):([0-9]+):([0-9]+)\)$/;

    /** Indicates if source map is loaded */
    public var ready (default,null) : Bool = false;

    /**
     * Invoke `callback` when source map is loaded.
     * A call to this method is automatically injected in `static main()` function of your app.
     * You don't need to use this method manually.
     */
    static public function onReady (callback:Void->Void) {
        onReadyCallback = callback;
        if (instance.ready) callback();
    }

    /**
     * Overwrite this method to handle uncaught exceptions manually.
     * Any returned value will be written to stderr.
     * @param e - Uncaught exception.  It's `js.Error` most of the time,
     *              but it also can be any other type if thrown outside of Haxe-generated code.
     */
    @:access(haxe.CallStack)
    static public dynamic function uncaughtExceptionHandler (e:Dynamic) : String {
        if(untyped __js__("{0} instanceof Error", e)) {
            var stack = CallStack.getStack(e).map(improveStackItem);
            var error = e.message + CallStack.toString(stack) + '\n';
            return error;
        } else {
            return 'Uncaught exception: ' + Std.string(e);
        }
    }

    function new () {
        if(isNode()) {
            untyped __js__('process.on("uncaughtException", {0})', _uncaughtExceptionHandler);
        }
        inject();
    }

    /**
     * Loads source map and injects hooks into `haxe.CallStack`.
     * It's asynchronous process so haxe-related positions in call stack might be not available right away.
     */
    public function inject () {
        loadSourceMap(function (sourceMapData:String) {
            mapper = new SourceMap(sourceMapData);

            CallStack.wrapCallSite = function (site) {
                var pos = mapper.originalPositionFor(site.getLineNumber(), site.getColumnNumber());
                return new StackPos(site, pos);
            }

            ready = true;
            if (onReadyCallback != null) {
                onReadyCallback();
            }
        });
    }


    /**
     * Load source map and pass it to `callback`
     */
    function loadSourceMap (callback : String->Void) {
        if (!isNode()) {
            loadInBrowser(callback);
        } else {
            loadInNode(callback);
        }
    }


    /**
     * Do the job in browser environment
     */
    function loadInBrowser (callback:String->Void) {
        var currDir = getCurrentDirInBrowser();
        var file = currDir != null ? currDir + '/' + Tools.getSourceMapFileName() : Tools.getSourceMapFileName();
        var http = new Http(file);

        http.onError = function (error:String) {
            trace(error);
        }
        http.onData = function (sourceMap:String) {
            callback(sourceMap);
        }
        http.request();
    }


    /**
     * Do the job in nodejs environment
     */
    public function loadInNode (callback:String->Void) {
        var dir : String = untyped __js__("__dirname");
        var fs = untyped __js__("require('fs')");

        fs.readFile(dir + '/' + Tools.getSourceMapFileName(), function(error, sourceMap) {
           if (error != null) {
               trace(error);
           } else {
               callback(sourceMap);
           }
        });
    }


    /**
     * Scans DOM for <script> tags to find current script directory
     */
    public function getCurrentDirInBrowser () : String {
        var file = Tools.getOutputFileName();
        var scripts = Browser.document.getElementsByTagName('script');

        var fullPath = './$file';
        for (i in 0...scripts.length) {
            var src = scripts.item(i).attributes.getNamedItem('src');
            if (src != null && src.value.indexOf(file) >= 0) {
                fullPath = src.value;
            }
        }
        var path = new Path(fullPath);

        return path.dir;
    }

    /**
     * Actual handler used for uncaught exceptions
     * @param e -
     */
    static function _uncaughtExceptionHandler (e:Dynamic) {
        var error = uncaughtExceptionHandler(e);
        if(error != null && error.length > 0) {
            untyped __js__('console.log({0})', error);
            if (isNode()) {
                untyped __js__('process.exit(1)');
            }
        }
    }

    /**
        Check if currently run on nodejs.
    **/
    static function isNode () : Bool {
        return untyped __js__("typeof window == 'undefined'");
    }

    /**
        Try to make a better stack.
    **/
    static function improveStackItem (item:StackItem) : StackItem {
        switch (item) {
            case Module(line) if (stackFile.match(line)):
                var file = stackFile.matched(1);
                if (file != currentFile()) return item;

                var line = Std.parseInt(stackFile.matched(2));
                var column = Std.parseInt(stackFile.matched(3));
                var pos = mapper.originalPositionFor(line, column);

                return FilePos(null, pos.source, pos.originalLine);

            case Module(line) if (stackFunctionFile.match(line)):
                var file = stackFunctionFile.matched(2);
                if (file != currentFile()) return item;

                var line = Std.parseInt(stackFunctionFile.matched(3));
                var column = Std.parseInt(stackFunctionFile.matched(4));
                var pos = mapper.originalPositionFor(line, column);

                if (pos == null) return item;

                var fn = stackFunctionFile.matched(1).split('.');
                var method = fn.pop();
                var cls = fn.join('.');
                var methodItem = (cls != null && method != null ? Method(cls, method) : null);

                return FilePos(methodItem, pos.source, pos.originalLine);

            case _:
                return item;
        }
    }

    /**
        Returns full name of currently being executed js file.
    **/
    static function currentFile () : Null<String> {
        if (isNode()) {
            return untyped __js__('__filename');
        }
        return null;
    }
}


/**
 * Represents call stack position
 */
@:keep
class StackPos {
    /** JS side */
    var js : Dynamic;
    /** HX side */
    var hx : Dynamic;

    public function new (js:Dynamic, hx:SourcePos) {
        this.js = js;
        this.hx = hx;
    }

    public function getFunctionName () return js.getFunctionName();
    public function getFileName () return (hx == null || hx.originalLine == null ? js.getFileName() : hx.source);
    public function getLineNumber () return (hx == null || hx.originalLine == null ? js.getLineNumber() : hx.originalLine);

}