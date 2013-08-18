#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

/* Note, this typdef must be coordinated with the signature used in
 * C::TinyCompiler::Callable::build_C_invoker!!
 */
typedef void (*invoker_func_ptr)(char*, char*);

MODULE = C::TinyCompiler::Callable           PACKAGE = C::TinyCompiler::Callable

IV
_get_pointer_address(in_scalar)
	SV * in_scalar
	CODE:
		/* If in_scalar is a ref, return the ref's PVx */
		if (SvROK(in_scalar)) {
			SV * deref = SvRV(in_scalar);
			if (SvPOK(deref)) {
				char * chr_deref = SvPV_nolen(deref);
				RETVAL = PTR2IV(chr_deref);
			}
			else {
				croak("Trying to get pointer to a variable that has no buffer!");
			}
		}
		/* If in_scalar is not a ref, then return its IV slot */
		else {
			RETVAL = SvIV(in_scalar);
		}
	OUTPUT:
		RETVAL

void
_call_invoker(function_ptr, in_pack, return_pack)
	SV * function_ptr
	char * in_pack
	char * return_pack
	CODE:
		/* Get the function pointer to the invoker, properly cast */
		invoker_func_ptr to_call
			= INT2PTR(invoker_func_ptr, SvIV(function_ptr));
		
		/* Call the invoker, passing the input and output buffers. I (must)
		 * assume that the output buffer has already been allocated. */
		to_call(in_pack, return_pack);
