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

assert 0 '0+0;'
assert 4 '1+3;'
assert 1 '2-1;'
assert 0 '1+2+3-6;'
assert 1 '1 + 10 - 10;'
assert 100 '255 + 100 - 100 - 155;'
assert 1 '1;'
assert 10 '- -10;'
assert 10 '- - +10;'
assert 15 '1+2+3*4;'
assert 1 '1+2/3*4;'
assert 2 '+1-2++3;'
assert 1 'if(0) return 2; return 1;'
assert 2 'if(1) return 2; return 1;'
assert 1 'if(0) return 2; else return 1;'
assert 2 'if(1) return 2; else return 1;'
assert 3 'a = 0; while (a < 3) a = a + 1; return a;'
assert 55 'i=0; j=0; for (i=0; i<=10; i=i+1) j=i+j; return j;'
assert 3 'for (;;) return 3; return 5;'
assert 6 'i=0; j=0; for (i=0; i <= 3; i =i+1)  {j=j+i;} return j;'
assert 0 'i=0; j=0; for (i=0; i <= 3; i =i+1)  {j=j+i; j=0;} return j;'
assert 3 'i=0; j=0; for (i=0; i <= 3; i =i+1)  {j=j+i; j=0; j=i;} return j;'

echo OK
