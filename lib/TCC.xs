#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

typedef TCCState TCCStateObj;

/* Error handling should store the message and return to the normal execution
 * order. In other words, croak is inappropriate here. */
void my_tcc_error_func (void * context, const char * msg ) {
	/* set the message in the error_message key of the compiler context */
	hv_store((HV*)context, "error_message", 13, newSVpv(msg, 0), 0);
}

typedef void (*my_func_caller_ptr)(AV*, AV*);

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
		tcc_set_output_type(state, TCC_OUTPUT_MEMORY);
		
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

# The next two are pretty much direct copies of each other

void
add_include_paths(state, ...)
	TCCStateObj * state
	PREINIT:
		char * path_name;
		int i, ret;
	CODE:
		for (i = 1; i < items; i++) {
			path_name = SvPVbyte_nolen(ST(i));
			ret = tcc_add_include_path(state, path_name);
			/* As of this time of writing, tcc_add_include always returns zero,
			 * but if that ever changes, this croak is ready to catch it */
			if (ret < 0) {
				croak("Unkown TCC error including path [%s]\n", path_name);
			}
		}

void
add_sysinclude_paths(state, ...)
	TCCStateObj * state
	PREINIT:
		char * path_name;
		int i, ret;
	CODE:
		for (i = 1; i < items; i++) {
			path_name = SvPVbyte_nolen(ST(i));
			ret = tcc_add_sysinclude_path(state, path_name);
			/* As of this time of writing, tcc_add_sysinclude always returns
			 * zero, but if that ever changes, this croak is ready to catch it */
			if (ret < 0) {
				croak("Unkown TCC error including syspath [%s]\n", path_name);
			}
		}

void
_define(state, symbol_name, value)
	TCCStateObj * state
	const char * symbol_name
	const char * value
	CODE:
		tcc_define_symbol(state, symbol_name, value);

void
_undefine(state, symbol_name)
	TCCStateObj * state
	const char * symbol_name
	CODE:
		tcc_undefine_symbol(state, symbol_name);

############ Libraries ############

void
add_libraries(state, ...)
	TCCStateObj * state
	PREINIT:
		char * lib_name;
		int i;
	CODE:
		for (i = 1; i < items; i++) {
			lib_name = SvPVbyte_nolen(ST(i));
			if (-1 == tcc_add_library(state, lib_name)) {
				/* Returns 0 on success, -1 on failure */
				croak("Unable to add library %s", lib_name);
			}
		}

void
add_library_paths(state, ...)
	TCCStateObj * state
	PREINIT:
		char * path;
		int i;
	CODE:
		for (i = 1; i < items; i++) {
			path = SvPVbyte_nolen(ST(i));
			tcc_add_library_path(state, path);
		}

############ Compiler ############
void
_compile(state, code)
	TCCStateObj * state
	const char * code
	CODE:
		/* Compile and croak if error */
		int ret = tcc_compile_string(state, code);
		if (ret != 0) croak("Compile error\n");

void
add_symbols(state, ...)
	TCCStateObj * state
	PREINIT:
		char * symbol_name;
		void * symbol_ptr;
	CODE:
		/* Make sure we've got an even number of arguments (aside from self) */
		if (items % 2 == 0) {
			croak("You must supply key => value pairs to add_symbols\n");
		}
		int i;
		for (i = 1; i < items; i += 2) {
			symbol_name = SvPVbyte_nolen(ST(i));
			symbol_ptr = INT2PTR(void*, SvIV(ST(i+1)));
			tcc_add_symbol(state, symbol_name, symbol_ptr);
		}

void
_relocate(state)
	TCCStateObj * state
	CODE:
		/* Relocate and croak if error */
		int ret = tcc_relocate(state);
		if (ret < 0) croak("Relocation error\n");

############ Post-Compiler ############
void
_call_function(state, func_name, input, output)
	TCCStateObj * state
	const char * func_name
	AV * input
	AV * output
	CODE:
		/* Get a pointer to the function */
		my_func_caller_ptr p_func
			= (my_func_caller_ptr)tcc_get_symbol(state, func_name);
		/* Croak if we encountered errors */
		if (p_func == 0) croak("Unable to locate %s", func_name);
		/* Call it with the arrays of inputs and outputs */
		p_func(input, output);

void
get_symbols(state, ...)
	TCCStateObj * state
	PREINIT:
		char * symbol_name;
		void * symbol_pointer;
		int i;
	PPCODE:
		EXTEND(SP, 2*items);
		for (i = 0; i < items; i++) {
			/* Get the tentative name */
			symbol_name = SvPVbyte_nolen(ST(i));
			
			/* Get a pointer to the symbol */
			symbol_pointer = tcc_get_symbol(state, symbol_name);
			
			/* croak if the symbol retrieval was not successful, as this is
			 * likely to be the result of a typo on the programmer's part */
			if (symbol_pointer == 0) croak("Unable to locate %s", symbol_name);
			
			/* Push the resulting key => value onto the return list */
			PUSHs(sv_2mortal(newSVpv(symbol_name, strlen(symbol_name))));
			PUSHs(sv_2mortal(newSViv(PTR2IV(symbol_pointer))));
		}

