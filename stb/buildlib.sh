clang -fPIC -c -fno-stack-protector -O3 -msse3 -DNDEBUG main.c 
ar rcs clibstb.a *.o
rm main.o
mv clibstb.a ../lib/clibstb.a