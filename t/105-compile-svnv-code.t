#!perl -T
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;

use TCC;
use TCC::AV;
use TCC::SV;

# The code to compile:
my $context= TCC->new;
$context->code('Body') = q{
	void test_func(AV * args) {
		
		double sum = 0;
		int i;
		for (i = 1; i <= av_len(args); i++) {
			sum += SvNV(*(av_fetch(args, i, 0)));
		}
		
		SV * to_return = (*(av_fetch(args, 0, 0)));
		sv_setnv(to_return, sum);
	}
};

############## simple code compilation: 3
eval {$context->compile};
is($@, '', "Compiling simple code works");

my $return;
eval {$context->call_function('test_func', $return, 1, 2, 3)};
is($@, '', 'Calling a compiled function does not croak');
is($return, 6, "Function returns the correct value");

