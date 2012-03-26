#!perl
# A test to check that the compiler works and can invoke code. In order to avoid
# the complications of interacting with the Perl API (which is a package and,
# therefore, a 200-level test), this uses printf statements from the compiled
# C code, executes the code in a seperate Perl process, and captures the output.

use 5.006;
use strict;
use warnings;
use Test::More tests => 4;

use inc::Capture;

my $results = Capture::it(<<'TEST_CODE');
use TCC;

# Build the context with some simple code:
my $context= TCC->new;
$context->code('Body') = q{
	void print_hello() {
		printf("Hello from TCC\n");
	}
};
$context->compile;
print "OK: compiled\n";

# Call the compiled function:
$context->call_function('print_hello');

print "Done\n";
TEST_CODE

############## simple code compilation: 1
isnt($results, undef, 'Got sensible results')
	or diag($results);
like($results, qr/OK: compiled/, "Compiles without trouble");
like($results, qr/Hello from TCC/, "Calls and executes a function");
like($results, qr/Done/, "Continues after the function call");
