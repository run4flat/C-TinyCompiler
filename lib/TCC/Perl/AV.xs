#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

typedef TCCState TCCStateObj;

void my_av_clear(AV * array) {
	av_clear(array);
}

SV ** my_av_fetch(AV * array, I32 index, I32 lvalue) {
	return av_fetch(array, index, lvalue);
}

int my_av_len(AV * av) {
	return av_len(av);
}

MODULE = TCC::Perl::AV           PACKAGE = TCC::Perl::AV

void
_apply_symbols(state)
	TCCStateObj* state
	CODE:
		tcc_add_symbol(state, "av_clear", my_av_clear);
		tcc_add_symbol(state, "av_fetch", my_av_fetch);
		tcc_add_symbol(state, "av_len", my_av_len);
