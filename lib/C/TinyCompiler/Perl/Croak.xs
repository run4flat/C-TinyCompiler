#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include <stdarg.h>

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

MODULE = C::TinyCompiler::Perl::Croak           PACKAGE = C::TinyCompiler::Perl::Croak

HV *
get_symbol_ptrs()
	CODE:
		RETVAL = newHV();
		/* add the function pointers */
		hv_store(RETVAL, "croak", 5, newSViv(PTR2IV(my_croak)), 0);
		hv_store(RETVAL, "warn", 4, newSViv(PTR2IV(my_warn)), 0);
		hv_store(RETVAL, "vcroak", 6, newSViv(PTR2IV(my_vcroak)), 0);
		hv_store(RETVAL, "vwarn", 5, newSViv(PTR2IV(my_vwarn)), 0);
	OUTPUT:
		RETVAL
