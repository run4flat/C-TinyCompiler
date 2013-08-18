#!perl
# A test of C::TinyCompiler::StretchyBuffer

use 5.006;
use strict;
use warnings;
use Test::More tests => 19;

# Needed for line numbering. :-)
use C::TinyCompiler;
use inc::Capture;

############## compile and run a simple printout function (make sure it compiles)

my $results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

 # Declare the compiler context with the stretchy buffer interface:
 my $context= C::TinyCompiler->new('::StretchyBuffer');
 
 # Create a function that uses stretchy buffers:
 $context->code('Body') = q{
     void test_func() {
         printf("OK: test_func called\n");
     }
 };
 
 # Compile and call:
 $context->compile;

print "OK: compiled\n";

 $context->call_void_function('test_func');

print "OK: Done\n";
TEST_CODE

############## simple code compilation: 3
isnt($results, undef, 'Successfully ran the script')
	or diag($results);
like($results, qr/OK: compiled/, 'StretchyBuffer code compiles fine');
like($results, qr/OK: test_func called/, 'By itself, StretchyBuffer does not cause runtime errors');


############## Test the interface

$results = Capture::it(C::TinyCompiler::line_number(__LINE__+1) . <<'TEST_CODE');

use C::TinyCompiler;

 # Declare the compiler context with the stretchy buffer interface:
 my $context= C::TinyCompiler->new('::StretchyBuffer');
 
 # Create a function that uses stretchy buffers:
 $context->code('Body') = C::TinyCompiler::line_number(__LINE__) . q{
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
         printf("List has %d available elements\n", sbcount(list));
         
          /* Set the last element */
         sblast(list) = 100;
         
         /* Pop the last element */
         printf("Last element was %f\n", sbpop(list));
         
         /* Get the list length and the allocated space */
         printf("After a pop, we have %d available elements\n", sbcount(list));
         
         /* Remove two elements */
         int remaining = sbremove(list, 2);
         printf("sbremove returned %d\n", remaining);
         
         /* Get the list length and the allocated space */
         printf("After remove, we have %d available elements\n", sbcount(list));
         
         int i;
         printf("List:\n");
         for (i = 0; i < sbcount(list); i++) {
             printf("%d: %f\n", i, list[i]);
         }
         
         /* When we're all done, free the memory, restoring the value to null */
         sbfree(list);
     }
 };
 
 # Compile and call:
 $context->compile;
 $context->call_void_function('test_func');

print "Done\n";
TEST_CODE

############## simple code compilation: 8
isnt($results, undef, 'Successfully ran the script')
	or diag($results);
like($results, qr/List has 8 available elements/, 'sbcount gives number of elements');
like($results, qr/Last element was 100\.\d+/, 'sblast respects lvalues, and pop works');
like($results, qr/After a pop, we have 7 available elements/, 'sbcount gives number of elements after a pop');
like($results, qr/sbremove returned 5/, 'sbremove returns the remaining number of elements');
like($results, qr/After remove, we have 5 available elements/, 'sbcount gives number of elements after a remove');
like($results, qr/0: 3\.2\d+\n1: -2\.9\d+\n2: 22\.\d+/, 'Elements stored and manipulated as documented');
like($results, qr/Done/, 'Everything runs without croaking');


############## Test operations on null pointers and empty lists

$results = Capture::it(C::TinyCompiler::line_number(__LINE__+1) . <<'TEST_CODE');

use C::TinyCompiler;

 # Declare the compiler context with the stretchy buffer interface:
 my $context= C::TinyCompiler->new('::StretchyBuffer');
 
 # Create a function that uses stretchy buffers:
 $context->code('Body') = C::TinyCompiler::line_number(__LINE__) . q{
     void test_func() {
         /* stretchy buffers always start and end as null pointers */
         double * list = 0;
         
         printf("Length for null vector: %d\n", sbcount(list));
         
         /* Freeing a null pointer is harmless */
         printf("Freeing... ");
         sbfree(list);
         printf("that went well\n");
         
         printf("Popping on a null vector gives: %f\n", sbpop(list));
         
         sbpush(list, 3);
         printf("First element is %f\n", list[0]);
         
         /* Remove the only element and see how many are reported */
         sbpop(list);
         printf("List is%s null and has %d elements\n", (list ? " not" : "")
			, sbcount(list));
         
         /* Popping list of zero length non-null list still works */
         sbpop(list);
         printf("List now has %d elements\n", sbcount(list));
         
         /* When we're all done, free the memory, restoring the value to null */
         sbfree(list);
     }
 };
 
 # Compile and call:
 $context->compile;
 $context->call_void_function('test_func');
 print "Done!\n";

print "Done\n";
TEST_CODE

############## null pointers: 8
isnt($results, undef, 'Successfully ran the script')
	or diag($results);
like($results, qr/Length for null vector: 0/, 'sbcount reports zero length for null vector');
like($results, qr/Freeing... that went well/, 'Freeing null vector does not croak');
like($results, qr/Popping on a null vector gives: 0[.\d]*/, 'popping null vector works and returns zero');
like($results, qr/First element is 3[.\d]*/, 'Pushing onto null vector works');
like($results, qr/List is not null and has 0 elements/, 'Popping off all elements works');
like($results, qr/List now has 0 elements/, 'Popping off a zero-length non-null list works');
like($results, qr/Done!/, 'Everything runs without croaking');

