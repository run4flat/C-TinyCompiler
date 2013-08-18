#!perl
# A test to check the C::TinyCompiler::Callable interface's regular expressions.

use strict;
use warnings;
use Test::More;
use C::TinyCompiler::Callable;

my $regex = C::TinyCompiler::Callable->function_parse_regex;

# Build a collection of simple function declarations to see if they are
# properly parsed by the Callable regex.

note('Function declarations that should pass');

# Note: the regex expects to start on whitespace (since it will be placed
# just *after* the callable package), so we have to add whitespace to the
# beginning of them.

note('Analyzing [ int my_sum(int a, int b)]');
like(' int my_sum(int a, int b)', $regex, 'int (int, int) passes');
is($C::TinyCompiler::Callable::matched_names[0], 'my_sum', 'Properly pulls out function name');
is($C::TinyCompiler::Callable::matched_types[0], 'int', 'Properly pulls out return type');
is($C::TinyCompiler::Callable::matched_names[1], 'a', 'Properly pulls out first argument name');
is($C::TinyCompiler::Callable::matched_types[1], 'int', 'Properly pulls out first argument type');
is($C::TinyCompiler::Callable::matched_names[2], 'b', 'Properly pulls out second argument name');
is($C::TinyCompiler::Callable::matched_types[2], 'int', 'Properly pulls out second argument type');

note('Analyzing [ int my_sum(int a, double b, char c)]');
like(' int foobar(int a, double b, char c)', $regex, 'int (int, double, char) passes');
is($C::TinyCompiler::Callable::matched_names[0], 'foobar', 'Properly pulls out function name');
is($C::TinyCompiler::Callable::matched_types[0], 'int', 'Properly pulls out return type');
is($C::TinyCompiler::Callable::matched_names[1], 'a', 'Properly pulls out first argument name');
is($C::TinyCompiler::Callable::matched_types[1], 'int', 'Properly pulls out first argument type');
is($C::TinyCompiler::Callable::matched_names[2], 'b', 'Properly pulls out second argument name');
is($C::TinyCompiler::Callable::matched_types[2], 'double', 'Properly pulls out second argument type');
is($C::TinyCompiler::Callable::matched_names[3], 'c', 'Properly pulls out third argument name');
is($C::TinyCompiler::Callable::matched_types[3], 'char', 'Properly pulls out third argument type');

my @function_declarations = split(/\n/, <<'DECLARATIONS');
 int my_sum(int a, int b)
 int my_sum(int alice , int b)
 unsigned int my_sum(unsigned int a, unsigned int bob)
 int my_sum(int alice, int bob )
 int my_sum ( int alice , int bob )
 unsigned int my_sum ( unsigned int alice , unsigned int bob )
DECLARATIONS

like($_, $regex, "[$_] passes the parse check") foreach (@function_declarations);

my $to_test = q{
	void get_height_and_temp (
		/* Input: location on the grid and time of day */
		grid * my_grid, int x, int y, int time,
		/* Output: height and temperature of that position at that time */
		double * height, double * temperature
	)
};
like($to_test, $regex, 'Multiline function declaration passes the parse check');

done_testing;
