#!perl
# A test of TCC::StretchyBuffer

use 5.006;
use strict;
use warnings;
use Test::More tests => 6;

use inc::Capture;

############## compile and run a simple printout function (make sure it compiles)

my $results = Capture::it(<<'TEST_CODE');
use TCC;

 # Declare the compiler context with the stretchy buffer interface:
 my $context= TCC->new('::StretchyBuffer');
 
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

my $results = Capture::it(<<'TEST_CODE');
use TCC;

 # Declare the compiler context with the stretchy buffer interface:
 my $context= TCC->new('::StretchyBuffer');
 
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

############## simple code compilation: 3
isnt($results, undef, 'Successfully ran the script')
	or diag($results);
like($results, qr/List has 8 elements, of which 3 are in use/, 'sblast and sbcount work as expected');
like($results, qr/3.2\n-2.9\n22/, 'Elements stored and manipulated as documented');

