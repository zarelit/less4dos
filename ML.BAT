@echo off
masm5 %2 %1,%1,%1,NUL
link2 %1,%1,NUL, ,NUL
%echo on
