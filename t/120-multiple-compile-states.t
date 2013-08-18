#!perl
# A test to check how C::TinyCompiler handles multiple compiles in a row, or multiple
# simultaneous compile states.

use 5.006;
use strict;
use warnings;
use Test::More tests => 26;

use inc::Capture;

############## one context, compile-call-compile-call-destroy: 5
note ('one context, compile-call-compile-call-destroy');

my $results = Capture::it(<<'TEST_CODE');
use strict;
use warnings;
use C::TinyCompiler;
# Autoflush
$|++;

# Build the context with some simple code:
my $context = C::TinyCompiler->new;
$context->code('Body') = q{
	void print_hello1() {
		printf("Hello1 from TCC\n");
	}
};
$context->compile;
print "Finished first compile\n";
$context->call_void_function('print_hello1');

# Remove the compile flag
$context->code('Body') = q{
	void print_hello2() {
		printf("Hello2 from TCC\n");
	}
};
eval {
	$context->compile;
	print "Finished second compile\n";
	# Call the two compiled functions:
	$context->call_void_function('print_hello2');
	1;
} or print $@;

undef($context);
print "Done\n";

TEST_CODE

like($results, qr/Finished first compile/, 'Completed first compile');
like($results, qr/Hello1 from TCC/, 'Can call function from first compile');
like($results, qr/already been compiled/, 'Second compile fails');
unlike($results, qr/Finished second compile/, 'Second compile fails (test 2)');
like($results, qr/Done/, 'Destruction does not cause a segfault');



############## two contexts, compile-call-destroy-compile-call-destroy: 5
note('two contexts, compile-call-destroy-compile-call-destroy');

$results = Capture::it(<<'TEST_CODE');
use strict;
use warnings;
use C::TinyCompiler;
# Autoflush
$|++;

# Build the context with some simple code:
my $context1 = C::TinyCompiler->new;
$context1->code('Body') = q{
	void print_hello1() {
		printf("Hello1 from TCC\n");
	}
};
$context1->compile;
$context1->call_void_function('print_hello1');
undef($context1);
print "Finished first context\n";

my $context2 = C::TinyCompiler->new;
$context2->code('Body') = q{
	void print_hello2() {
		printf("Hello2 from TCC\n");
	}
};
$context2->compile;
print "Finished second compile\n";
# Call the two compiled functions:
$context2->call_void_function('print_hello2');

undef($context2);
print "Finished second context\n";

TEST_CODE

like($results, qr/Hello1 from TCC/, 'Call function from first compile');
like($results, qr/Finished first context/, 'Safely destroy first context');
like($results, qr/Finished second compile/, 'Completed second compile');
like($results, qr/Hello2 from TCC/, 'Call function from second compile');
like($results, qr/Finished second context/, 'Safely destroy second context');



############## two contexts, compile-call-compile-destroy-call-destroy: 5
note('two contexts, compile-call-compile-destroy-call-destroy');

$results = Capture::it(<<'TEST_CODE');
use strict;
use warnings;
use C::TinyCompiler;
# Autoflush
$|++;

# Build the context with some simple code:
my $context1 = C::TinyCompiler->new;
$context1->code('Body') = q{
	void print_hello1() {
		printf("Hello1 from TCC\n");
	}
};
$context1->compile;
$context1->call_void_function('print_hello1');

my $context2 = C::TinyCompiler->new;
$context2->code('Body') = q{
	void print_hello2() {
		printf("Hello2 from TCC\n");
	}
};
$context2->compile;
print "Finished second compile\n";

# Destroy the first context
undef($context1);
print "Destroyed first context\n";

# Call the two compiled functions:
$context2->call_void_function('print_hello2');

undef($context2);
print "Finished second context\n";

TEST_CODE

like($results, qr/Hello1 from TCC/, 'Call function from first compile');
like($results, qr/Finished second compile/, 'Completed second compile');
like($results, qr/Destroyed first context/, 'Safely destroy first context');
like($results, qr/Hello2 from TCC/, 'Call function from second compile');
like($results, qr/Finished second context/, 'Safely destroy second context');



############## two contexts, compile-call-compile-call-destroy-destroy: 5
note('two contexts, compile-call-compile-call-destroy-destroy');

$results = Capture::it(<<'TEST_CODE');
use strict;
use warnings;
use C::TinyCompiler;
# Autoflush
$|++;

# Build the context with some simple code:
my $context1 = C::TinyCompiler->new;
$context1->code('Body') = q{
	void print_hello1() {
		printf("Hello1 from TCC\n");
	}
};
$context1->compile;
$context1->call_void_function('print_hello1');

my $context2 = C::TinyCompiler->new;
$context2->code('Body') = q{
	void print_hello2() {
		printf("Hello2 from TCC\n");
	}
};
$context2->compile;
print "Finished second compile\n";

# Call the two compiled functions:
$context2->call_void_function('print_hello2');

# Destroy the first context
undef($context1);
print "Destroyed first context\n";

undef($context2);
print "Finished second context\n";

TEST_CODE

like($results, qr/Hello1 from TCC/, 'Call function from first compile');
like($results, qr/Finished second compile/, 'Completed second compile');
like($results, qr/Hello2 from TCC/, 'Call function from second compile');
like($results, qr/Destroyed first context/, 'Safely destroy first context');
like($results, qr/Finished second context/, 'Safely destroy second context');



############## two contexts, compile-compile-call-call-destroy-destroy: 6
note('two contexts, compile-compile-call-call-destroy-destroy');

$results = Capture::it(<<'TEST_CODE');
use strict;
use warnings;
use C::TinyCompiler;
# Autoflush
$|++;

# Build the context with some simple code:
my $context1 = C::TinyCompiler->new;
$context1->code('Body') = q{
	void print_hello1() {
		printf("Hello1 from TCC\n");
	}
};
$context1->compile;
print "Finished first compile\n";

my $context2 = C::TinyCompiler->new;
$context2->code('Body') = q{
	void print_hello2() {
		printf("Hello2 from TCC\n");
	}
};
$context2->compile;
print "Finished second compile\n";

# Call the two compiled functions:
eval {
	$context1->call_void_function('print_hello1');
	1;
} or do {
	print "Could not call print_hello1\n";
};

eval {
	$context2->call_void_function('print_hello2');
	1;
} or do {
	print "Could not call print_hello2\n";
};

# Destroy the first context
eval {undef($context1) };
print "Destroyed first context\n";

eval {undef($context2)};
print "Destroyed second context\n";

TEST_CODE

like($results, qr/Finished first compile/, 'Completed first compile');
like($results, qr/Finished second compile/, 'Completed second compile');
like($results, qr/Hello1 from TCC/, 'Call function from first compile');
like($results, qr/Hello2 from TCC/, 'Call function from second compile');
like($results, qr/Destroyed first context/, 'Safely destroy first context');
like($results, qr/Destroyed second context/, 'Safely destroy second context');
