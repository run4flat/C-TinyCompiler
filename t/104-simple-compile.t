#!perl -T
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 1;

use TCC;

############## simple code compilation: 1
my $first_context= TCC->new;
$first_context->code('Body') = q{
	void silly_test_add() {
		int a = 1;
		int b = 2;
		int c = a + b;
	}
};

eval {$first_context->compile};
is($@, '', "Compiling simple code works");

