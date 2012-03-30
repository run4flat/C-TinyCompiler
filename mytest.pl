#!perl
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;

use blib;
use TCC;

############## simple code compilation: 1
my $context= TCC->new;
 $context->code('Body') .= q{
     void test_func (int a {
         printf("Success!\n");
     }
 };

$context->compile;
$context->call_void_function('test_func');
