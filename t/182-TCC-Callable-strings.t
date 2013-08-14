use 5.006;
use strict;
use warnings;
use Test::More;

# Tests that strings are properly passed to the C functions. This also
# tests, essentially, that pointers are handled properly.

use inc::Capture;

my $test_string = 'Hello from TCC::Callable!';
my $context = '$context';

my $results = Capture::it(qq{
	use strict;
	use warnings;
	use TCC;
	
	# Build the context with some simple code:
	my $context = TCC->new('::Callable');
	$context->code('Body') = q{
		TCC::Callable
		void print_string (char * input) {
			printf("%s\n", input);
		}
	};
	$context->compile;

	my \$to_try = '$test_string';
	$context->get_callable_subref('print_string')->(\\\$to_try);
});
like($results, qr/$test_string/, 'String is properly passed');

done_testing;