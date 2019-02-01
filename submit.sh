#!/bin/bash

rm jstack.zip
zip -r jstack.zip src format README.md LICENSE haxelib.json extraParams.hxml > /dev/null
haxelib submit jstack.zip