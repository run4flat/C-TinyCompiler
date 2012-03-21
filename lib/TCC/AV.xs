#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

SV ** my_av_fetch(AV * array, I32 index, I32 lvalue) {
	return av_fetch(array, index, lvalue);
}

I32 my_av_len(AV * av) {
	return av_len(av);
}

MODULE = TCC::AV           PACKAGE = TCC::AV

void
_add_basic_AV_functions(state)
	TCCState * state
	CODE:
		/* Really simple stuff for now */
		printf("adding av_fetch\n"); fflush(stdout);
		tcc_add_symbol(state, "av_fetch", my_av_fetch);
		printf("adding av_len\n"); fflush(stdout);
		tcc_add_symbol(state, "av_len", my_av_len);
		printf("done\n"); fflush(stdout);

