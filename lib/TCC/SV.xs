#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

void my_sv_setnv (SV * sv, NV num) {
	sv_setnv(sv, num);
}

double my_SvNV (SV * scalar) {
	return SvNV(scalar);
}

int my_SvIV (SV * scalar) {
	return SvIV(scalar);
}

MODULE = TCC::SV           PACKAGE = TCC::SV

HV *
get_symbol_ptrs()
	CODE:
		RETVAL = newHV();
		/* add the function pointers */
		hv_store(RETVAL, "SvNV", 4, newSViv(PTR2IV(my_SvNV)), 0);
		hv_store(RETVAL, "SvIV", 4, newSViv(PTR2IV(my_SvIV)), 0);
		hv_store(RETVAL, "sv_setnv", 8, newSViv(PTR2IV(my_sv_setnv)), 0);
	OUTPUT:
		RETVAL

