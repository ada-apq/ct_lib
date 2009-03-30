# Makefile for the AW_Lib
#
# @author Marcelo Coraça de Freitas <marcelo.batera@gmail.com> 


projectFile="apq-ct_lib.gpr"


libs: c_libs
	gnatmake -P ${projectFile}



c_objs:
	make -C src-c/

c_objs-clean:
	make -C src-c/ clean



apq-ct_lib.ads:
	make -C extras

apq-ct_lib.ads-clean:
	make -C extras clean
	rm -f src/apq-ct_lib.ads


c_libs: apq-ct_lib.ads c_objs
	cd lib && gcc -shared  ../obj-c/c_ct_lib.o -o libapq-ct_libhelp.dll  -lct

#c_objs:
#	cd obj-c && gcc -I../src-c ../src-c/numeric.c -c -o numeric.o && gcc -I../src-c ../src-c/notices.c -c -o notices.o

all: libs


clean: apq-ct_lib.ads-clean c_objs-clean
	@rm -f obj-c/* lib/*
	gnatclean -P ${projectFile}
	@echo "All clean"

docs:
	@-./gendoc.sh
	@echo "The documentation is generated by a bash script. Then it might fail in other platforms"


