#!perl
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;

use blib;
warn __LINE__, "\n";
use TCC;

warn __LINE__, "\n";

############## simple code compilation: 1
my $context= TCC->new;
warn __LINE__, "\n";
use TCC::AV;
warn __LINE__, "\n";
$context->code('Body') = q{
	void av_len_test(AV * args) {
		printf("Length of args is %i\n", av_len(args));
	}
};

warn __LINE__, "\n";
$context->compile;
warn __LINE__, "\n";
$context->call_function('av_len_test', 1, 2, 3);
warn __LINE__, "\n";
