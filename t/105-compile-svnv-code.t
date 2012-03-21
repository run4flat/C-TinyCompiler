#!perl
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 1;

use TCC;

############## simple code compilation: 1
my $context= TCC->new;
use TCC::AV;
use TCC::SV::NV;
# add nv functions:
$context->add_basic_AV_functions;
$context->add_basic_SV_nv_functions;
$context->code('Body') = q{
	void nv_test(AV * args) {
		printf("Length of args is %i\n", av_len(args));
	}
};

eval {$context->compile};
is($@, '', "Compiling simple code works");

$context->call_function('nv_test', 1, 2, 3);
