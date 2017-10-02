package jstack;

#if (debug || JSTACK_FORCE)

#if js
typedef JStack = jstack.js.JStack;
#elseif (php && (php7 || JSTACK_HAXE_DEV))
typedef JStack = jstack.php7.JStack;
#end

#end