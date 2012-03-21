#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

SV ** my_av_fetch(AV * array, I32 index, I32 lvalue) {
	return av_fetch(array, index, lvalue);
}

int my_av_len(AV * av) {
	return av_len(av);
}

MODULE = TCC::AV           PACKAGE = TCC::AV

HV *
get_symbol_ptrs()
	CODE:
		RETVAL = newHV();
		/* add the function pointers */
		hv_store(RETVAL, "av_fetch", 8, newSViv(PTR2IV(my_av_fetch)), 0);
		hv_store(RETVAL, "av_len", 6, newSViv(PTR2IV(my_av_len)), 0);
	OUTPUT:
		RETVAL
