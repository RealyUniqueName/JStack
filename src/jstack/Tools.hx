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
    static public function addInjectMetaToMain() : Void
    {
        #if (display || !debug)
            return;
        #end
        if (Context.definedValue('js') == null) return;

        var main : String = null;
        var args = Sys.args();
        for (i in 0...args.length) {
            if(args[i] == '-main') {
                main = args[i + 1];
                break;
            }
        }
        if (main == null) {
            Context.warning('JStack: Failed to find entry point. Did you specify `-main` directive?', (macro {}).pos);
            return;
        }

        Compiler.addMetadata('@:build(jstack.Tools.injectInMain())', main);
    }
#end

    macro static public function injectInMain() : Array<Field>
    {
        var fields = Context.getBuildFields();
        var injected = false;

        for (field in fields) {
            if (field.name != 'main') continue;

            switch (field.kind) {
                case FFun(fn):
                    fn.expr = macro jstack.JStack.onReady(function() ${fn.expr});
                    injected = true;
                case _:
                    Context.error('JStack: Failed to inject JStack in `main` function.', field.pos);
            }
        }

        if (!injected) {
            Context.error('JStack: Failed to find static function main.', (macro {}).pos);
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


    /**
     * Embeds source-map js library into compiled file
     */
    macro static public function embedSourceMapLib () : Expr
    {
        var dir = Context.currentPos().getPosInfos().file.directory();
        var libFile = dir + '/' + SOURCE_MAP_LIB_FILE;
        var libCode = libFile.getContent();

        return macro untyped __js__($v{libCode});
    }


    public function new () {
    }
}
