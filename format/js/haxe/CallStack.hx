package haxe;

enum StackItem {
	CFunction;
	Module( m : String );
	FilePos( s : Null<StackItem>, file : String, line : Int );
	Method( classname : String, method : String );
	LocalFunction( ?v : Int );
}

/**
	Get information about the call stack.
**/
class CallStack {
#if js
	static var lastException:js.Error;

	static function getStack(e:js.Error):Array<StackItem> {
		if (e == null) return [];
		// https://code.google.com/p/v8/wiki/JavaScriptStackTraceApi
		var oldValue = (untyped Error).prepareStackTrace;
		(untyped Error).prepareStackTrace = function (error, callsites :Array<Dynamic>) {
			var stack = [];
			for (site in callsites) {
				if (wrapCallSite != null) site = wrapCallSite(site);
				var method = null;
				var fullName:String = site.getFunctionName();
				if (fullName != null) {
					var idx = fullName.lastIndexOf(".");
					if (idx >= 0) {
						var className = fullName.substr(0, idx);
						var methodName = fullName.substr(idx+1);
						method = Method(className, methodName);
					}
				}
				stack.push(FilePos(method, site.getFileName(), site.getLineNumber()));
			}
			return stack;
		}
		var a = makeStack(e.stack);
		(untyped Error).prepareStackTrace = oldValue;
		return a;
	}

	// support for source-map-support module
	@:noCompletion
	public static var wrapCallSite:Dynamic->Dynamic;

	/**
		Return the call stack elements, or an empty array if not available.
	**/
	public static function callStack() : Array<StackItem> {
		try {
			throw new js.Error();
		} catch( e : Dynamic ) {
			var a = getStack(e);
			a.shift(); // remove Stack.callStack()
			return a;
		}
	}

	/**
		Return the exception stack : this is the stack elements between
		the place the last exception was thrown and the place it was
		caught, or an empty array if not available.
	**/
	public static function exceptionStack() : Array<StackItem> {
		return untyped __define_feature__("haxe.CallStack.exceptionStack", getStack(lastException));
	}

	/**
		Returns a representation of the stack as a printable string.
	**/
	public static function toString( stack : Array<StackItem> ) {
		return jstack.Format.toString(stack);
	}

	private static function makeStack(s #if cs : cs.system.diagnostics.StackTrace #elseif hl : hl.NativeArray<hl.Bytes> #end) {
		if (s == null) {
			return [];
		} else if ((untyped __js__("typeof"))(s) == "string") {
			// Return the raw lines in browsers that don't support prepareStackTrace
			var stack : Array<String> = s.split("\n");
			if( stack[0] == "Error" ) stack.shift();
			var m = [];
			var rie10 = ~/^   at ([A-Za-z0-9_. ]+) \(([^)]+):([0-9]+):([0-9]+)\)$/;
			for( line in stack ) {
				if( rie10.match(line) ) {
					var path = rie10.matched(1).split(".");
					var meth = path.pop();
					var file = rie10.matched(2);
					var line = Std.parseInt(rie10.matched(3));
					m.push(FilePos( meth == "Anonymous function" ? LocalFunction() : meth == "Global code" ? null : Method(path.join("."),meth), file, line ));
				} else
					m.push(Module(StringTools.trim(line))); // A little weird, but better than nothing
			}
			return m;
		} else {
			return cast s;
		}
	}
#else
	static public function callStack():Array<StackItem> throw "Not implemented. See https://github.com/RealyUniqueName/JStack/issues/10";
	static public function exceptionStack():Array<StackItem> throw "Not implemented. See https://github.com/RealyUniqueName/JStack/issues/10";
	static public function toString(stack : Array<StackItem>):String throw "Not implemented. See https://github.com/RealyUniqueName/JStack/issues/10";
#end
}
