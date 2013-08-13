#!perl
# A test to check the TCC Callable interface

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
my $context = TCC->new('::Callable');
$context->code('Body') = q{
	/* Comment */
	TCC::Callable
	int my_sum (int a, int b) {
		return a + b;
	}
	TCC::Callable
	double my_pow (double value, double exponent) {
		printf("Input value is %d; exponent is %d\n", value, exponent);
		return pow(value, exponent);
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

$context = TCC->new('::Callable');
$context->code('Body') = q{
	TCC::Callable
	int check_string ( char * input ) {
		printf("In TCC string code, got input pointer of %p\n", input);
		char * expected = "hello, TCC!";
		while(*expected && *input && (*expected) == (*input)) {
			expected++; input++;
		}
		if ((*expected) == 0) return 1;
		return 0;
	}
};
$context->compile;
my $match = $context->get_callable_subref('check_string')->(\$string);
use Devel::Peek;
Dump(\$string);
ok($match, 'Strings should match') or do {
	diag("Full code was:
---- Head ----
" . $context->code('Head') . "
---- Body ----
" . $context->code('Body') . "
---- Foot ----
" . $context->code('Foot') . "
");
	diag("Perl invoker is
----
$context->{Callable}{check_string}{subref_string}
----");
};

done_testing;
__END__

#################################
# Check that packed arrays work #
#################################
note('Packed arrays');
my @values = map { rand() } (1..10);
my $sum = 0;
$sum += $_ for @values;
my $doubles_buffer = pack('d*', @values);

$context = TCC->new('::Callable');
$context->code('Body') = q{
	TCC::Callable
	double my_sum (double * list, int length) {
		int i;
		printf("From C code, list's address is %p\n", list);
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
ok(abs($C_sum - $sum) / abs($sum) < 1e-5, 'Handles pointers correctly') or do {
	diag("Got C-sum of $C_sum and Perl-sum of $sum");
	diag("Full code was:
---- Head ----
" . $context->code('Head') . "
---- Body ----
" . $context->code('Body') . "
---- Foot ----
" . $context->code('Foot') . "
");
	diag("Perl invoker is
----
$context->{Callable}{my_sum}{subref_string}
----");
};

###########################################
# Check that we get useful error messages #
###########################################
note('Error messages');

$context = TCC->new('::Callable');
$context->code('Body') = q{
	typedef int something_crazy;
	
	TCC::Callable
	int double_it(something_crazy val) {
		printf("Hello, %d\n", val);
		return (val*2);
	}
};
eval {$context->compile};
like($@, qr/Unknown type/, 'Unknown types are caught at "compile" time');

done_testing;
