rm a.out
rm *.o
clang -O2 impl.c bcopy.s musl_memcpy.s gmemcpy.s -c
clang++ -O2 -std=c++17 bench_memcpy_aarch64.cc impl.o bcopy.o musl_memcpy.o gmemcpy.o
