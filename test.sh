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
 ./swift-cc -raw "$input" > tmp.s || exit

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

assert 0 'int main() {0+0;}'
assert 4 'int main() {1+3;}'
assert 1 'int main() {2-1;}'
assert 0 'int main() {1+2+3-6;}'
assert 1 'int main() {1 + 10 - 10;}'
assert 100 'int main() {255 + 100 - 100 - 155;}'
assert 1 'int main() {1;}'
assert 10 'int main() {- -10;}'
assert 10 'int main() {- - +10;}'
assert 15 'int main() {1+2+3*4;}'
assert 1 'int main() {1+2/3*4;}'
assert 2 'int main() {+1-2++3;}'
assert 1 'int main() {if(0) return 2; return 1;}'
assert 2 'int main() {if(1) return 2; return 1;}'
assert 1 'int main() {if(0) return 2; else return 1;}'
assert 2 'int main() {if(1) return 2; else return 1;}'
assert 3 'int main() {int a = 0; while (a < 3) a = a + 1; return a;}'
assert 55 'int main() {int i=0; int j=0; for (i=0; i<=10; i=i+1) j=i+j; return j;}'
assert 3 'int main() {for (;;) return 3; return 5;}'
assert 6 'int main() {int i=0; int j=0; for (i=0; i <= 3; i =i+1)  {j=j+i;} return j;}'
assert 0 'int main() {int i=0; int j=0; for (i=0; i <= 3; i =i+1)  {j=j+i; j=0;} return j;}'
assert 3 'int main() {int i=0; int j=0; for (i=0; i <= 3; i =i+1)  {j=j+i; j=0; j=i;} return j;}'

assert 3 'int main() { return ret3(); }'
assert 8 'int main() { return ret8(); }'

assert 1 'int main() { return retArg1(1); }'
assert 3 'int main() { return retArg2(2, 1); }'
assert 6 'int main() { return retArg3(1, 2, 3); }'
assert 10 'int main() { return retArg4(1, 2, 3, 4); }'
assert 15 'int main() { return retArg5(1, 2, 3, 4, 5); }'
assert 21 'int main() { return retArg6(1, 2, 3, 4, 5, 6); }'

assert 32 'int main() { return ret32(); } int ret32() { return 32; }'

assert 7 'int main() { return add2(3, 4); } int add2(int x, int y) { return x+y; }'
assert 1 'int main() { return sub2(3, 2); } int sub2(int x, int y) { return x-y; }'
assert 55 'int main() { return fib(9); } int fib(int x) { if (x<=1) return 1; return fib(x-1) + fib(x-2); }'

assert 3 'int main() { int x=3; int *y=&x; int **z=&y; return **z; }'
assert 5 'int main() { int x=3; int y=5; return *(&x-8); }'
assert 3 'int main() { int x=3; int y=5; return *(&y+8); }'
assert 7 'int main() { int x=3; int y=5; *(&x-8)=7; return y; }'
assert 7 'int main() { int x=3; int y=5; *(&y+8)=7; return x; }'

assert 3 'int main() { int x=3; return *&x; }'
assert 3 'int main() { int x=3; int *y=&x; int **z=&y; return **z; }'
assert 5 'int main() { int x=3; int y=5; return *(&x-8); }'
assert 3 'int main() { int x=3; int y=5; return *(&y+8); }'
assert 5 'int main() { int x=3; int y=5; int *z=&x; return *(z-8); }'
assert 3 'int main() { int x=3; int y=5; int *z=&y; return *(z+8); }'
assert 5 'int main() { int x=3; int *y=&x; *y=5; return x; }'
assert 7 'int main() { int x=3; int y=5; *(&x-8)=7; return y; }'
assert 7 'int main() { int x=3; int y=5; *(&y+8)=7; return x; }'
assert 8 'int main() { int x=3; int y=5; return foo(&x, y); } int foo(int *x, int y) { return *x + y; }'

# cleanup
rm tmp*

echo OK
