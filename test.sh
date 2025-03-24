#!/bin/bash

_clear () {
  rm  tmp tmp.s
}
assert() {
 expected="$1"
 input="$2"
 ./swift-cc "$input" > tmp.s || exit

 cc -o tmp tmp.s

 ./tmp

 actual="$?"

 _clear

 if [ "$actual" = "$expected" ]; then
   echo "$input => $actual"
 else
   echo "$input => $expected expected, but got $actual"
   exit 1
 fi
}

assert 0 0
assert 42 42

echo OK
