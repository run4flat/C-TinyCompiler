#!perl
# A test to check that the compiler works and can invoke code.

use 5.006;
use strict;
use warnings;
use Test::More tests => 17;

use inc::Capture;

############## compile and run a simple printout function

my $results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

# Build the context with some simple code:
my $context= C::TinyCompiler->new;
$context->code('Body') = q{
	void print_hello() {
		printf("Hello from TinyCompiler\n");
	}
};
$context->compile;
print "OK: compiled\n";

# Call the compiled function:
$context->call_void_function('print_hello');

print "Done\n";
TEST_CODE

############## simple code compilation: 4
isnt($results, undef, 'Got sensible results')
	or diag($results);
like($results, qr/OK: compiled/, "Compiles without trouble");
like($results, qr/Hello from TinyCompiler/, "Calls and executes a function");
like($results, qr/Done/, "Continues after the function call");

############## exercise the #define behavior within tcc: 1

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;
my $context = C::TinyCompiler->new;
$context->code('Body') = q{
	#define PRINT(arg) printf(arg)
	void print_hello() {
		PRINT("Hello from TCC\n");
	}
};
$context->compile;
$context->call_void_function('print_hello');
TEST_CODE

like($results, qr/Hello from TCC/, 'Simple in-code define');

############## exercise the Perl-side define function: 1

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;
my $context = C::TinyCompiler->new;
$context->define('PRINT(arg)' => 'printf(arg)');
$context->code('Body') = q{
	void print_hello() {
		PRINT("Hello from TCC\n");
	}
};
$context->compile;
$context->call_void_function('print_hello');
TEST_CODE

like($results, qr/Hello from TCC/, 'Perl in-code define');

############## variadic macros in C::TinyCompiler: 3

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;
my $context = C::TinyCompiler->new;
my %variadic = qw(
	...			__VA_ARGS__
	args...		args
	arg,...		arg,__VA_ARGS__
);
my $i = 0;
while (my ($input, $output) = each %variadic) {
	$context->code('Body') .= qq{
		#define PRINT$i($input) printf($output)
		void print$i() {
			PRINT$i("input %s\n", "$input");
		}
	};
	$i++;
}
$context->compile;
$i = 0;
for (keys %variadic) {
	$context->call_void_function("print$i");
	$i++;
}
TEST_CODE

like($results, qr/input .../, 'Variadic macro define func(...) in tcc');
like($results, qr/input args.../, 'Variadic macro define func(args...) in tcc');
like($results, qr/input arg,.../, 'Variadic macro define func(arg,...) in tcc');

############## variadic macros from Perl: 3

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;
my $context = C::TinyCompiler->new;
my %variadic = qw(
	...			__VA_ARGS__
	args...		args
	arg,...		arg,__VA_ARGS__
);
my $i = 0;
while (my ($input, $output) = each %variadic) {
	$context->code('Body') .= qq{
		void print$i() {
			PRINT$i("input %s\n", "$input");
		}
	};
	$context->define("PRINT$i($input)" => "printf($output)");
	$i++;
}
$context->compile;
$i = 0;
for (keys %variadic) {
	$context->call_void_function("print$i");
	$i++;
}
TEST_CODE

like($results, qr/input .../, 'Variadic macro define func(...) from Perl');
like($results, qr/input args.../, 'Variadic macro define func(args...) from Perl');
like($results, qr/input arg,.../, 'Variadic macro define func(arg,...) from Perl');

############## token pasting in C::TinyCompiler and from Perl: 2
# Tests an example in the docs, under the define method. Update the note in
# this docs if this is removed or moved to a different file.

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;
my $context = C::TinyCompiler->new;

# Define it Perl-side:
$context->define('DEBUG_PRINT_INT1(val)'
     , 'printf("For " #val ", got %d\n", val)');

$context->code('Body') .= q{
	/* Define it tcc-side */
	#define DEBUG_PRINT_INT2(val) printf("For " #val ", got %d\n", val)
	
	void test() {
		int a = 1;
		int b = 2;
		DEBUG_PRINT_INT1(a);
		DEBUG_PRINT_INT2(b);
	}
};
$context->compile;
$context->call_void_function("test");
TEST_CODE

like($results, qr/For a, got 1/, 'Perl-side token pasting macros');
like($results, qr/For b, got 2/, 'tcc-side token pasting macros');

############## Multiline macros: 1
# Tests whether multiline macros are allowed.

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;
my $context = C::TinyCompiler->new;

# Define it Perl-side:
$context->define ('DEBUG_PRINT_INT1(val)' => q{
	do {
		printf("For " #val ", got %d\n", val);
	} while (0)
});

$context->code('Body') .= q{
	void test() {
		int a = 1;
		int b = 2;
		DEBUG_PRINT_INT1(a);
	}
};
$context->compile;
$context->call_void_function("test");
TEST_CODE

like($results, qr/For a, got 1/, 'Multiline macros are ok');

############## Undefining macros: 2
# Tests that undefining of macros works

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;
my $context = C::TinyCompiler->new;

# Define it Perl-side:
$context->define (ONE);
$context->define (TWO);

# undefine one from Perl-side:
$context->undefine (ONE);

$context->code('Head') .= q{
	#undef TWO
};
$context->code('Body') .= q{
	void test() {
		#ifdef ONE
			printf("ONE is defined\n");
		#else
			printf("ONE is not defined\n");
		#endif
		#ifdef TWO
			printf("TWO is defined\n");
		#else
			printf("TWO is not defined\n");
		#endif
	}
};
$context->compile;
$context->call_void_function("test");
TEST_CODE

like($results, qr/ONE is not defined/, 'Perl-side undefine');
like($results, qr/TWO is not defined/, 'C-side undefine');

