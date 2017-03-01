package jstack;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.Context;
using sys.io.File;
using StringTools;
using haxe.io.Path;
#end


/**
 * Macro tools
 */
class Tools {
#if macro
    static private inline var SOURCE_MAP_LIB_FILE = '../../js/source-map.min.js';

    /**
        Inject `json.JStack.onReady()` into app entry point, so that app will not start untill source map is ready.
    **/
    static public function addInjectMetaToEntryPoint() : Void
    {
        #if (display || !(debug || JSTACK_FORCE))
            return;
        #end
        if (!Context.defined('js') && !Context.defined('php7')) return;
        Compiler.define('js_source_map');
        Compiler.define('source_map');

        var entryClass : String = null;
        var entryMethod : String = null;

        if (Context.defined('JSTACK_MAIN')) {
            var jstackMain = Context.definedValue('JSTACK_MAIN');

            if (jstackMain == null || jstackMain.length == 0 || jstackMain == '1') {
                Context.error('JSTACK_MAIN should have a value. E.g.: -D JSTACK_MAIN=my.SomeClass.entryPoint', (macro {}).pos);
            }

            var parts = jstackMain.split('.');
            if (parts.length < 2) {
                Context.error('JSTACK_MAIN value should have a class name and a function name. E.g.: -D JSTACK_MAIN=my.SomeClass.entryPoint', (macro {}).pos);
            }
            entryMethod = parts.pop();
            entryClass = parts.join('.');
        }

        if (entryClass == null) {
            var args = Sys.args();
            for (i in 0...args.length) {
                if(args[i] == '-main') {
                    entryClass = args[i + 1];
                    entryMethod = 'main';
                    break;
                }
            }
        }

        if (entryClass == null) {
            Context.warning('JStack: Failed to find entry point. Did you specify `-main` or `-D JSTACK_MAIN`?', (macro {}).pos);
            return;
        }

        Compiler.addMetadata('@:build(jstack.Tools.injectInEntryPoint("$entryMethod"))', entryClass);
    }
#end

    macro static public function injectInEntryPoint(method:String) : Array<Field>
    {
        var fields = Context.getBuildFields();
        var injected = false;

        for (field in fields) {
            if (field.name != method) continue;

            switch (field.kind) {
                case FFun(fn):
                    fn.expr = macro jstack.JStack.onReady(function() ${fn.expr});
                    injected = true;
                case _:
                    Context.error('JStack: Failed to inject JStack in `$method` function.', field.pos);
            }
        }

        if (!injected) {
            Context.error('JStack: Failed to find entry point method "$method".', (macro {}).pos);
        }

        return fields;
    }

    /**
     * Returns file name of generated output
     */
    macro static public function getOutputFileName () : ExprOf<String>
    {
        var file = Compiler.getOutput().withoutDirectory();

        return macro $v{file};
    }


    /**
     * Get source map file name for current app
     */
    macro static public function getSourceMapFileName () : ExprOf<String>
    {
        var file = Compiler.getOutput().withoutDirectory();

        return macro $v{file} + '.map';
    }


    // /**
    //  * Embeds source-map js library into compiled file
    //  */
    // macro static public function embedSourceMapLib () : Expr
    // {
    //     var dir = Context.currentPos().getPosInfos().file.directory();
    //     var libFile = dir + '/' + SOURCE_MAP_LIB_FILE;
    //     var libCode = libFile.getContent();

    //     return macro untyped __js__($v{libCode});
    // }
}
