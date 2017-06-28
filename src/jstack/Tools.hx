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
        Initialization macro. To be called with `--macro`
    **/
    static public function initialize () {
        #if (display || !(debug || JSTACK_FORCE)) return; #end
        if (Context.defined('display') || !(Context.defined('debug') || Context.defined('JSTACK_FORCE'))) return;
        if (!Context.defined('js') && !Context.defined('php7')) return;

        if (Context.defined('JSTACK_FORMAT')) {
            if(Context.defined('js')) {
                Compiler.addClassPath(getJstackRootDir() + 'format/js');
            } else if(Context.defined('php7')) {
                Compiler.addClassPath(getJstackRootDir() + 'format/php7');
            } else {
                throw 'Unexpected behavior';
            }
        }

        addInjectMetaToEntryPoint();
    }

    /**
        Inject `json.JStack.onReady()` into app entry point, so that app will not start untill source map is ready.
    **/
    static public function addInjectMetaToEntryPoint() : Void {
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

    /**
        Get root directory of JStack haxelib.
    **/
    static function getJstackRootDir () : String {
        var toolsFile = Context.getPosInfos((macro {}).pos).file;
        toolsFile = toolsFile.replace('\\', '/');
        var dir = toolsFile.split('/').slice(0, -3).join('/');
        return (dir == '' ? '.' : dir) + '/';
    }
#end

    macro static public function injectInEntryPoint(method:String) : Array<Field> {
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
    macro static public function getOutputFileName () : ExprOf<String> {
        var file = Compiler.getOutput().withoutDirectory();

        return macro $v{file};
    }

    /**
     * Get source map file name for current app
     */
    macro static public function getSourceMapFileName () : ExprOf<String> {
        var file = Compiler.getOutput().withoutDirectory();

        return macro $v{file} + '.map';
    }

    /**
        Returns a template for formatting entries in call stack.
        Supported placeholders: %file% %line% %symbol%
    **/
    macro static public function getFormat () : ExprOf<String> {
        return switch (Context.definedValue('JSTACK_FORMAT')) {
            case 'vscode':
                switch (Sys.systemName()) {
                    case 'Windows': macro 'Called from %symbol% file://%file%#%line%';
                    case _: macro 'Called from %symbol% file://%file%:%line%';
                }
            case 'idea': macro '%file%:%line% in %symbol%';
            case format: macro $v{format};
        }
    }
}
