#!perl
# A test to check the general C::TinyCompiler::Callable interface. At this point we've
# used inc::Capture to be sure that values are properly passed into and out
# of the C functions. Now we can start calling the functions directly and
# checking their return values.

use 5.006;
use strict;
use warnings;
use Test::More;
use C::TinyCompiler;

######################
# Simple code checks #
######################
note('Simple checks that should succeed');

# Build the context with two simple functions:
my $context = C::TinyCompiler->new('::Callable');
$context->code('Body') = q{
	/* Comment */
	C::TinyCompiler::Callable
	int my_sum (int a, int b) {
		return a + b;
	}
	C::TinyCompiler::Callable
	double my_pow (double value, int exponent) {
		double to_return = 1;
		while (exponent --> 0) to_return *= value;
		return to_return;
	}
};
$context->compile;
my $my_sum = eval { $context->get_callable_subref('my_sum') };
is($@, '', 'get_callable_subref does not croak for a valid function declaration with ints');
is($my_sum->(1, 2), 3, 'Provides a viable function that works correctly');
my $my_pow_subref = eval { $context->get_callable_subref('my_pow') };
is($@, '', 'get_callable_subref does not croak on doubles');
is($my_pow_subref->(3, 3), 27, 'Double inputs and outputs work fine');

###########
# Strings #
###########

note('Strings');
my $string = 'hello, TCC!';

$context = C::TinyCompiler->new('::Callable');
$context->code('Body') = qq{
	C::TinyCompiler::Callable
	int check_string ( char * input ) {
		char * expected = "$string";
		while(*expected && *input && (*expected) == (*input)) {
			expected++; input++;
		}
		if ((*expected) == 0) return 1;
		return 0;
	}
};
$context->compile;
my $match = $context->get_callable_subref('check_string')->(\$string);
ok($match, 'Strings should match');

#################################
# Check that packed arrays work #
#################################
note('Packed arrays');
my @values = map { rand() } (1..10);
my $sum = 0;
$sum += $_ for @values;
my $doubles_buffer = pack('d*', @values);

$context = C::TinyCompiler->new('::Callable');
$context->code('Body') = q{
	C::TinyCompiler::Callable
	double my_sum (double * list, int length) {
		int i;
		double to_return = 0;
		for (i = 0; i < length; i++) {
			to_return += list[i];
		}
		return to_return;
	}
};
$context->compile;
$my_sum = $context->get_callable_subref('my_sum');
my $C_sum = $my_sum->(\$doubles_buffer, scalar(@values));
ok(abs($C_sum - $sum) / abs($sum) < 1e-5, 'Handles pointers correctly')
	or diag("Got C-sum of $C_sum and Perl-sum of $sum");

###########################################
# Check that we get useful error messages #
###########################################
note('Error messages');

$context = C::TinyCompiler->new('::Callable');
$context->code('Body') = q{
	typedef int something_crazy;
	
	C::TinyCompiler::Callable
	int double_it(something_crazy val) {
		printf("Hello, %d\n", val);
		return (val*2);
	}
};
eval {$context->compile};
like($@, qr/Unknown type/, 'Unknown types are caught at "compile" time');

done_testing;
