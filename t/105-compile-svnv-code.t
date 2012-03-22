#!perl
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;

use TCC;

# The code to compile:
my $context= TCC->new(packages => ['::Perl::AV', '::Perl::SV']);
$context->code('Body') = '#line ' . (__LINE__ + 1) . q{
	void test_func(AV * inputs, AV * outputs) {
		
		double sum = 0;
		int i;
		for (i = 0; i <= av_len(inputs); i++) {
			sum += SvNV(*(av_fetch(inputs, i, 0)));
		}
		
		SV * to_return = (*(av_fetch(outputs, 0, 1)));
		sv_setnv(to_return, sum);
	}
};

############## simple code compilation: 3
eval {$context->compile};
is($@, '', "Compiling simple code works");

my ($return) = eval {$context->call_function('test_func', 1, 2, 3)};
is($@, '', 'Calling a compiled function does not croak');
is($return, 6, "Function returns the correct value");

