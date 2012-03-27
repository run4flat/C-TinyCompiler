#!perl
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;

use blib;
use TCC;

############## simple code compilation: 1
my $context= TCC->new(packages => '::Perl');
$context->code('Body') = "#line " . (__LINE__+1) . ' "' . __FILE__ . q{"
	void av_len_test(AV * args) {
		printf("you passed in %d arguments\n", av_len(args)+1);
		
		double sum = 0;
		int i;
		for (i = 0; i <= av_len(args); i++) {
			SV ** value_ptr = av_fetch(args, i, 0);
			if (value_ptr == 0) printf("Unable to retrieve value %d", i);
			sum += SvNV(*value_ptr);
		}
		printf("Sum of the values is %f\n", sum);
		
		SV ** value_ptr = av_fetch(args, 8, 0);
		if (value_ptr == 0) printf("Unable to retrieve value %d\n", 8);
	}
};

$context->compile;
$context->call_function('av_len_test', 1, 2, 3);
$context->call_function('av_len_test', 1..10);
