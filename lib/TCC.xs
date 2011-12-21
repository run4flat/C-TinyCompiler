#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

/* Error handling should store the message and return to the normal execution
 * order. In other words, croak is inappropriate here. */
void my_tcc_error_func (void * context, const char * msg ) {
	/* set the message in the error_message key of the compiler context */
	hv_store((HV*)context, "error_message", 13, newSVpv(msg, 0), 0);
}


MODULE = TCC           PACKAGE = TCC

############ Creation/Delection ############

HV *
_new()
	CODE:
		/* create a new hashref */
		RETVAL = newHV();
		
		/* create a new state with error handling */
		TCCState * state = tcc_new();
		if (!state) {
			croak("Unable to create TCC compiler state!\n");
		}
		tcc_set_error_func(state, RETVAL, my_tcc_error_func);
		
		/* Add the state to the context */
		hv_store(RETVAL, "_state", 6, newSViv(PTR2IV(state)), 0);
	OUTPUT:
		RETVAL

void
DESTROY(context)
	HV * context
	CODE:
		/* Retrieve and delete the state from the context */
		SV * state_sv = hv_delete(context, "_state", 6, 0);
		
		/* Free the compiler state memory XXX not thread-safe */
		IV state = SvIV(state_sv);
		tcc_delete(INT2PTR(TCCState *, state));

############ Preprocessor ############

/* The next two are pretty much direct copies of each other */

void
_add_include_path(state, pathname)
	TCCState * state
	const char * pathname
	CODE:
		int ret = tcc_add_include_path(state, pathname);
		/* As of this time of writing, tcc_add_include always returns zero,
		 * but if that ever changes, this croak is read to catch it */
		if (ret < 0) croak("Error including path [%s]: unkown tcc error\n", pathname);


void
_add_sysinclude_path(state, pathname)
	TCCState * state
	const char * pathname
	CODE:
		int ret = tcc_add_sysinclude_path(state, pathname);
		/* As of this time of writing, tcc_add_sysinclude always returns zero,
		 * but if that ever changes, this croak is read to catch it */
		if (ret < 0) croak("Error including syspath [%s]: unknown tcc error\n", pathname);

void
_define(state, symbol_name, value)
	TCCState * state
	const char * symbol_name
	const char * value
	CODE:
		tcc_define_symbol(state, symbol_name, value);

void
_undefine(state, symbol_name)
	TCCState * state
	const char * symbol_name
	CODE:
		tcc_undefine_symbol(state, symbol_name);

############ Compiler ############
