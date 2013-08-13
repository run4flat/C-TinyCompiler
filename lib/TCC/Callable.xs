#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include <stdio.h>

/* Note, this typdef must be coordinated with the signature used in
 * TCC::Callable::build_C_invoker!!
 */
typedef void (*invoker_func_ptr)(char*, char*);

MODULE = TCC::Callable           PACKAGE = TCC::Callable

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
_call_invoker(function_ptr, in_pack_SV, return_pack_SV)
	SV * function_ptr
	SV * in_pack_SV
	SV * return_pack_SV
	CODE:
		/* Get the function pointer to the invoker, properly cast */
		invoker_func_ptr to_call
			= INT2PTR(invoker_func_ptr, SvIV(function_ptr));
		/* Call the invoker, passing the input and output buffers. I (must)
		 * assume that the output buffer has already been allocated. */
		char * in_pack = SvPV_nolen(in_pack_SV);
		printf("in_pack's address is %p\n", in_pack);
		double my_d;
		memcpy(&my_d, in_pack, sizeof(my_d));
		void * my_p;
		memcpy(&my_p, in_pack, sizeof(my_p));
		printf("first four bytes as a double: %d; memcpy: %d\n", *((double*) in_pack), my_d);
		printf("first four bytes as a pointer: %p; memcpy: %p\n", *((void**) in_pack), my_p);
		char * return_pack = SvPV_nolen(return_pack_SV);
		to_call(in_pack, return_pack);
