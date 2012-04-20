#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"
#include <stdarg.h>

typedef TCCState TCCStateObj;

void my_croak(const char * pat, ...) {
	va_list args;
	vcroak(pat, &args);
}

void my_warn(const char * pat, ...) {
	va_list args;
	vwarn(pat, &args);
}

void my_vcroak(const char *pat, va_list *args) {
	vcroak(pat, args);
}

void my_vwarn(const char *pat, va_list *args) {
	vwarn(pat, args);
}

MODULE = TCC::Perl::Croak           PACKAGE = TCC::Perl::Croak

void
_apply_symbols(state)
	TCCStateObj* state
	CODE:
		tcc_add_symbol(state, "croak", my_croak);
		tcc_add_symbol(state, "warn", my_warn);
		tcc_add_symbol(state, "vcroak", my_vcroak);
		tcc_add_symbol(state, "vwarn", my_vwarn);
