package TCC::StretchyBuffer;
use strict;
use warnings;
use parent 'TCC::package';

sub apply {
	my (undef, $state) = @_;
	
	# Add the stretchy buffer code:
	$state->code('Head') .= TCC::line_number(__LINE__) . q{
	
		#define sbfree(a)         ((a) ? free(stb__sbraw(a)),0 : 0)
		#define sbpush(a,v)       (stb__sbmaybegrow(a,1), (a)[stb__sbn(a)++] = (v))
		#define sbcount(a)        ((a) ? stb__sbn(a) : 0)
		#define sbadd(a,n)        (stb__sbmaybegrow(a,n), stb__sbn(a)+=(n), &(a)[stb__sbn(a)-(n)])
		#define sblast(a)         ((a)[stb__sbn(a)-1])

		#include <stdlib.h>
		#define stb__sbraw(a) ((int *) (a) - 2)
		#define stb__sbm(a)   stb__sbraw(a)[0]
		#define stb__sbn(a)   stb__sbraw(a)[1]

		#define stb__sbneedgrow(a,n)  ((a)==0 || stb__sbn(a)+n >= stb__sbm(a))
		#define stb__sbmaybegrow(a,n) (stb__sbneedgrow(a,(n)) ? stb__sbgrow(a,n) : 0)
		#define stb__sbgrow(a,n)  stb__sbgrowf((void **) &(a), (n), sizeof(*(a)))

		static void stb__sbgrowf(void **arr, int increment, int itemsize)
		{
			int m = *arr ? 2*stb__sbm(*arr)+increment : increment+1;
			void *p = realloc(*arr ? stb__sbraw(*arr) : 0, itemsize * m + sizeof(int)*2);
			assert(p);
			if (p) {
				if (!*arr) ((int *) p)[1] = 0;
				*arr = (void *) ((int *) p + 2);
				stb__sbm(*arr) = m;
			}
		}

		#line 1 "whatever comes after TCC::StretchyBuffer"
	};
}

1;

__END__

=head1 NAME

TCC::StretchyBuffer - Enabling stretchy buffers in your context

=head1 SYNOPSIS

 use TCC;
 
 # Declare the compiler context with the stretchy buffer interface:
 my $context= TCC->new('::StretchyBuffer');
 
 # Or add the interface afterwards:
 my $context = TCC->new;
 $context->add_packages('::StretchyBuffer');
 
 # Create a function that uses stretchy buffers:
 $context->code('Body') = q{
     void test_func() {
         /* stretchy buffers always start and end as null pointers */
         double * list = 0;
         
         /* Push some values onto the list */
         sbpush(list, 3.2);
         sbpush(list, -2.9);
         sbpush(list, 5);
         
         /* Eh, let's change that last one */
         list[2] = 22;
         
         /* Allocate room for five more */
         sbadd(list, 5);
         
         /* Get the list length and the allocated space */
         printf("list has %d elements, of which %d are in use\n"
             , sblast(list)+1, sbcount(list));
         
         int i;
         printf("List:\n");
         for (i = 0; i <= sbcount(list); i++) {
             printf("%d: %f\n", i, list[i]);
         }
         
         /* When we're all done, free the memory, restoring the value to null */
         sbfree(list);
     }
 };
 
 # Compile and call:
 $context->compile;
 $context->call_void_function('test_func');

=head1 DESCRIPTION

This TCC package provides Sean Barrett's implementation of stretchy buffers.
(For more of Sean Barrett's cool work, see his website at http://nothings.org/)

Stretchy buffers look like arrays with an exceptionally easy to use interface
for extending them and pushing new values onto them. 
