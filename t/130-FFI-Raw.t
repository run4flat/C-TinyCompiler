#!perl
# A test to check how TCC handles multiple compiles in a row, or multiple
# simultaneous compile states.

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;

############## see if it wraps and parses things correctly: 5

use TCC;

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
