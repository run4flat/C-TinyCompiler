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

MODULE = TCC::SV           PACKAGE = TCC::SV

void
_add_basic_SV_functions(state)
	TCCState * state
	CODE:
		/* right now this amounts to SvNV and sv_setnv */
		tcc_add_symbol(state, "SvNV", &my_SvNV);
		tcc_add_symbol(state, "sv_setnv", &my_sv_setnv);

