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
    static private inline var SOURCE_MAP_LIB_FILE = '../../js/source-map.min.js';


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
