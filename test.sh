#!/bin/bash

cat <<EOF | clang -xc -c -o tmp2.o -
int ret3() { return 3; }
int ret8() { return 8; }
EOF

cat <<EOF | clang -xc -c -o tmp3.o -
int retArg1(int x) { return x; }
int retArg2(int x, int y) { return x + y; }
int retArg3(int x, int y, int z) { return x + y + z ; }
int retArg4(int x1, int x2, int x3, int x4) { return x1 + x2 + x3 + x4; }
int retArg5(int x1, int x2, int x3, int x4, int x5) { return x1 + x2 + x3 + x4 + x5; }
int retArg6(int x1, int x2, int x3, int x4, int x5, int x6) { return x1 + x2 + x3 + x4 + x5 + x6; }
EOF

_clear () {
  rm  tmp tmp.s
}
assert() {
 expected="$1"
 input="$2"
 ./swift-cc "$input" > tmp.s || exit

 cc -o tmp tmp.s tmp2.o tmp3.o

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

assert 3 'return ret3();'
assert 8 'return ret8();'

assert 1 'return retArg1(1);'
assert 3 'return retArg2(2, 1);'
assert 6 'return retArg3(1, 2, 3);'
assert 10 'return retArg4(1, 2, 3, 4);'
assert 15 'return retArg5(1, 2, 3, 4, 5);'
assert 21 'return retArg6(1, 2, 3, 4, 5, 6);'

echo OK
