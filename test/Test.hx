package;

import haxe.io.Path;
import haxe.PosInfos;
import haxe.CallStack;

class Test {
	static var pos:PosInfos;

	static public function main() {
		throwException();
		try {
			throwException();
		} catch(e:Int) {
			var fileName = new Path(pos.fileName).file;
			for(stackItem in CallStack.exceptionStack()) {
				switch(stackItem) {
					case FilePos(_, file, line) if(line == pos.lineNumber && fileName == new Path(file).file):
						trace('Test passed');
						return;
					case _:
				}
			}
		}
		throw "Test FAILED";
	}

	static function throwException(?pos:PosInfos) {
		Test.pos = pos;
		throw 'wtf';
	}
}