# Makefile for the KOW Generic Library Framework
#
# @author Marcelo Coraça de Freitas <marcelo@kow.com.br> 
#
#
# Please, read Makefile.include for more information


all:
	./scripts/build.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh
clean:
	./scripts/clean.sh
	@rm -f src/apq-ct_lib.ads

distclean: 
	@-${MAKE} clean
	@-${MAKE} -C samples clean
