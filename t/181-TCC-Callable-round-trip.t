use 5.006;
use strict;
use warnings;
use Test::More;

# Tests types and return values with round-trip tests, using the actual
# printf'd values from the C code to validate.

use inc::Capture;

# I will try this basic script with different types:
my %types = (
	'int' => {
		test_val => -42,
		printf_key => 'd',
	},
	char => {
		test_val => ord('a'),
		printf_key => 'd',
	},
	float => {
		test_val => 0.125,
		printf_key => 'f',
	},
	double => {
		test_val => 0.125,
		printf_key => 'f',
	},
);


while (my ($type, $params_hash) = each %types) {
	my $context = '$context';
	my $test_val = $params_hash->{test_val};
	my $results = Capture::it(qq{
		use strict;
		use warnings;
		use C::TinyCompiler;

		# Build the context with some simple code:
		my $context = C::TinyCompiler->new('::Callable');
		$context->code('Body') = q{
			C::TinyCompiler::Callable
			$type round_trip ($type input) {
				printf("Got input %$params_hash->{printf_key}\n", input);
				return input;
			}
		};
		$context->compile;

		print "Returned ", $context->get_callable_subref('round_trip')->($test_val)
			, "\n";
	});

	# Make sure it completed
	like($results, qr/Returned/, "$type test script executed without trouble")
		or diag("Script completed with this output: $results");

	# Extract the input
	like($results, qr/Got input $test_val/, "Correct test value reached function");
	like($results, qr/Returned $test_val/, "Test value made round trip successfully");
}

done_testing;