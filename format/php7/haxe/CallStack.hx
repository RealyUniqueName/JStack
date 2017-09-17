package haxe;

#if (php7 && !macro)
import php.*;

private typedef NativeTrace = NativeIndexedArray<NativeAssocArray<Dynamic>>;
#end

/**
	Elements return by `CallStack` methods.
**/
enum StackItem {
	CFunction;
	Module( m : String );
	FilePos( s : Null<StackItem>, file : String, line : Int );
	Method( classname : String, method : String );
	LocalFunction( ?v : Int );
}

class CallStack {
#if (php7 && !macro)
	/**
		If defined this function will be used to transform call stack entries.
		@param String - generated php file name.
		@param Int - Line number in generated file.
	*/
	static public var mapPosition : String->Int->Null<{?source:String, ?originalLine:Int}>;

	@:ifFeature("haxe.CallStack.exceptionStack")
	static var lastExceptionTrace : NativeTrace;

	/**
		Return the call stack elements, or an empty array if not available.
	**/
	public static function callStack() : Array<StackItem> {
		return makeStack(Global.debug_backtrace(Const.DEBUG_BACKTRACE_IGNORE_ARGS));
	}

	/**
		Return the exception stack : this is the stack elements between
		the place the last exception was thrown and the place it was
		caught, or an empty array if not available.
	**/
	public static function exceptionStack() : Array<StackItem> {
		return makeStack(lastExceptionTrace == null ? new NativeIndexedArray() : lastExceptionTrace);
	}

	/**
		Returns a representation of the stack as a printable string.
	**/
	public static function toString( stack : Array<StackItem> ) {
		return jstack.Format.toString(stack);
	}

	@:ifFeature("haxe.CallStack.exceptionStack")
	static function saveExceptionTrace( e:Throwable ) : Void {
		lastExceptionTrace = e.getTrace();

		//Reduce exception stack to the place where exception was caught
		var currentTrace = Global.debug_backtrace(Const.DEBUG_BACKTRACE_IGNORE_ARGS);
		var count = Global.count(currentTrace);

		for (i in -(count - 1)...1) {
			var exceptionEntry:NativeAssocArray<Dynamic> = Global.end(lastExceptionTrace);

			if(!Global.isset(exceptionEntry['file']) || !Global.isset(currentTrace[-i]['file'])) {
				Global.array_pop(lastExceptionTrace);
			} else if (currentTrace[-i]['file'] == exceptionEntry['file'] && currentTrace[-i]['line'] == exceptionEntry['line']) {
				Global.array_pop(lastExceptionTrace);
			} else {
				break;
			}
		}

		//Remove arguments from trace to avoid blocking some objects from GC
		var count = Global.count(lastExceptionTrace);
		for (i in 0...count) {
			lastExceptionTrace[i]['args'] = new NativeArray();
		}

		var thrownAt = new NativeAssocArray<Dynamic>();
		thrownAt['function'] = '';
		thrownAt['line'] = e.getLine();
		thrownAt['file'] = e.getFile();
		thrownAt['class'] = '';
		thrownAt['args'] = new NativeArray();
		Global.array_unshift(lastExceptionTrace, thrownAt);
	}

	static function makeStack (native:NativeTrace) : Array<StackItem> {
		var result = [];
		var count = Global.count(native);

		for (i in 0...count) {
			var entry = native[i];
			var item = null;

			if (i + 1 < count) {
				var next = native[i + 1];

				if(!Global.isset(next['function'])) next['function'] = '';
				if(!Global.isset(next['class'])) next['class'] = '';

				if ((next['function']:String).indexOf('{closure}') >= 0) {
					item = LocalFunction();
				} else if ((next['class']:String).length > 0 && (next['function']:String).length > 0) {
					var cls = Boot.getClassName(next['class']);
					item = Method(cls, next['function']);
				}
			}
			if (Global.isset(entry['file'])) {
				if (mapPosition != null) {
					var pos = mapPosition(entry['file'], entry['line']);
					if (pos != null && pos.source != null && pos.originalLine != null) {
						entry['file'] = pos.source;
						entry['line'] = pos.originalLine;
					}
				}
				result.push(FilePos(item, entry['file'], entry['line']));
			} else if (item != null) {
				result.push(item);
			}
		}

		return result;
	}
#else
	static public function callStack():Array<StackItem> throw "Not implemented. See https://github.com/RealyUniqueName/JStack/issues/10";
	static public function exceptionStack():Array<StackItem> throw "Not implemented. See https://github.com/RealyUniqueName/JStack/issues/10";
	static public function toString():String throw "Not implemented. See https://github.com/RealyUniqueName/JStack/issues/10";
#end
}