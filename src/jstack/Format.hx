package jstack;

import haxe.CallStack.StackItem;

using StringTools;

/**
    Call stack formatting utils.
**/
class Format {
    public static function toString (stack:Array<StackItem>) : String {
        var format = Tools.getFormat();
        var buf = new StringBuf();
        for (item in stack) {
            if(format == null) {
                buf.add('\nCalled from ');
                itemToString(buf, item);
            } else {
                buf.add('\n');
                buf.add(itemToFormat(format, item));
            }
        }
        return buf.toString();
    }

    static function itemToString (buf:StringBuf, item:StackItem) {
        switch (item) {
            case CFunction:
                buf.add('a C function');
            case Module(m):
                buf.add('module ');
                buf.add(m);
            case FilePos(item, file, line):
                if( item != null ) {
                    itemToString(buf, item);
                    buf.add(' (');
                }
                buf.add(file);
                buf.add(' line ');
                buf.add(line);
                if (item != null) buf.add(')');
            case Method(cname,meth):
                buf.add(cname);
                buf.add('.');
                buf.add(meth);
            case LocalFunction(n):
                buf.add('local function #');
                buf.add(n);
        }
    }

    static function itemToFormat (format:String, item:StackItem) : String {
        switch (item) {
            case CFunction:
                return 'a C function';
            case Module(m):
                return 'module $m';
            case FilePos(s,file,line):
                if(file.substr(0, 'file://'.length) == 'file://') {
                    file = file.substr('file://'.length);
                }
                var symbol = (s == null ? '' : itemToFormat(format, s));
                return format.replace('%file%', file).replace('%line%', '$line').replace('%symbol%', symbol);
            case Method(cname,meth):
                return '$cname.$meth';
            case LocalFunction(n):
                return 'local function #$n';
        }
    }
}