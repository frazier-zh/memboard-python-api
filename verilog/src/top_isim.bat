REM Edit path for settings32/64, depending on architecture
call %XILINX%\..\settings64.bat

fuse -intstyle ise ^
     -incremental ^
     -lib unisims_ver ^
     -lib unimacro_ver ^
     -lib xilinxcorelib_ver ^
     -i ./oksim ^
     -o top_isim.exe ^
     -prj top_isim.prj ^
     work.Top_tb work.glbl
top_isim.exe -gui -tclbatch top_isim.tcl -wdb top_isim.wdb