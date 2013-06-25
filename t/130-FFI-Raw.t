#!perl
# A test to check the TCC FFI interface.

use 5.006;
use strict;
use warnings;
use Test::More;
use TCC;

######################
# Simple code checks #
######################
note('Simple checks that should succeed');

# Build the context with some simple code:
my $context = TCC->new;
$context->code('Body') = q{
	int my_sum (int a, int b) {
		return a + b;
	}
};
$context->compile;
my $my_sum = eval { $context->get_func_ref('my_sum') };
is($@, '', 'get_func_ref does not croak for a valid function declaration');
is($my_sum->(1, 2), 3, 'Provides a viable function that works correctly');

#################################
# Check that packed arrays work #
#################################
note('Packed arrays');
my @values = map { rand() } (1..10);
my $sum = 0;
$sum += $_ for @values;
my $doubles_buffer = pack('d*', @values);

$context = TCC->new;
$context->code('Body') = q{
	double my_sum (char * list_c, int length) {
		double * list = (double *) list_c;
		int i;
		double to_return = 0;
		for (i = 0; i < length; i++) {
			to_return += list[i];
		}
		return to_return;
	}
};
$context->compile;
$my_sum = $context->get_func_ref('my_sum');
my $C_sum = $my_sum->($doubles_buffer, scalar(@values));
ok(abs($C_sum - $sum) / abs($sum) < 1e-5, 'Handles pointers correctly');

###########################################
# Check that we get useful error messages #
###########################################
note('Error messages');

$context = TCC->new;
$context->code('Body') = q{
	/* still need to define printf */
	#define one another
	void one () {
		printf("Hello, world\n");
	}
	typedef int something_crazy;
	int double_it(something_crazy val) {
		printf("Hello, %d\n", val);
		return (val*2);
	}
};
$context->compile;

my $doesnt_exist = eval { $context->get_func_ref('another') };
like($@, qr/in body, but it did not look like a declaration/, 
	'Gives an error when it found a function string, but not a parsable declaration');
my $double_func = eval { $context->get_func_ref('double_it') };
like($@, qr/Unknown type/, 'Croaks on unknown types');

done_testing;
