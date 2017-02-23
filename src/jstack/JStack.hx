package jstack;

#if (js && (debug || JSTACK_FORCE))

import haxe.CallStack;
import sourcemap.SourcePos;
import js.Lib;
import haxe.io.Path;
import js.Browser;
import haxe.Http;

using StringTools;

/**
 * Handles source map
 */
class JStack {

    /** Create instance just to invoke `inject()` */
    static private var instance = new JStack();
    /** User-defined callback which will be invoked when sourceMap is loaded */
    static private var onReadyCallback : Void->Void;

    /** Indicates if source map is loaded */
    public var ready (default,null) : Bool = false;


    /**
     * Invoke `callback` when source map is loaded.
     * A call to this method is automatically injected in `static main()` function of your app.
     * You don't need to use this method manually.
     */
    static public function onReady (callback:Void->Void) : Void
    {
        onReadyCallback = callback;
        if (instance.ready) callback();
    }


    private function new ()
    {
        inject();
    }


    /**
     * Loads source map and injects hooks into `haxe.CallStack`.
     * It's asynchronous process so haxe-related positions in call stack might be not available right away.
     */
    public function inject () : Void
    {
        loadSourceMap(function (sourceMapData:String) {
            var mapper = new SourceMap(sourceMapData);

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
    private function loadSourceMap (callback : String->Void) : Void
    {
        if (untyped __js__("typeof window != 'undefined'")) {
            loadInBrowser(callback);
        } else {
            loadInNode(callback);
        }
    }


    /**
     * Do the job in browser environment
     */
    private function loadInBrowser (callback:String->Void) : Void
    {
        var file = getCurrentDirInBrowser() + '/' + Tools.getSourceMapFileName();
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
    public function loadInNode (callback:String->Void) : Void
    {
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
    public function getCurrentDirInBrowser () : String
    {
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

}


/**
 * Represents call stack position
 */
@:keep
private class StackPos
{
    /** JS side */
    private var js : Dynamic;
    /** HX side */
    private var hx : Dynamic;

    public function new (js:Dynamic, hx:SourcePos)
    {
        this.js = js;
        this.hx = hx;
    }

    public function getFunctionName () return js.getFunctionName();
    public function getFileName () return (hx == null || hx.originalLine == null ? js.getFileName() : hx.source);
    public function getLineNumber () return (hx == null || hx.originalLine == null ? js.getLineNumber() : hx.originalLine);

}

#end