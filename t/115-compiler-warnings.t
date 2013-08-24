#!perl
# A test to make sure that C::TinyCompiler handles compiler errors and
# warnings, and differentiates between the two.

use 5.006;
use strict;
use warnings;
use Test::More;
use Test::Warn;
use C::TinyCompiler;

## Single warning ##
my $context = C::TinyCompiler->new;
$context->code('Body') .= q{
	#warning "This is only a test"
};

# Test::Warnings API:
##my $warning_message = eval { warning { $context->compile } };
# No dying:
#is($@, '', 'Compiler warning did not cause compiler to croak');
## Got the right message
#like($warning_message, qr/This is only a test/, 'Warning text was properly warned');

# Test::Warn API
eval {
	warning_like { $context->compile } qr/This is only a test/,
		'Warning text was properly warned';
	pass('Compiler warning did not cause the compiler to croak');
} or fail('Compiler warning caused the compiler to croak');


## Multiple warnings ##
$context = C::TinyCompiler->new;
$context->code('Body') .= q{
	#warning "Test1"
	#warning "Test2"
};

eval {
	TODO: {
		local $TODO = 'Does not yet support multiple warnings.';
		warnings_like { $context->compile } [ qr/Test1/, qr/Test2/ ],
			'Both first and second warning are issued';
	};
	pass('Multiple compiler warnings did not cause the compiler to croak');
} or fail('Multiple compiler warnings caused the compiler to croak');
my $warning_message = eval { warning { $context->compile } };

# Test::Warnings API:
#$warning_message = eval { warning { $context->compile } };
## No dying:
#is($@, '', 'Multiple compiler warning did not cause compiler to croak');
#TODO: {
#	local $TODO = 'Does not yet support multiple warnings.';
#	like($warning_message, qr/Test1/, 'First warning was properly warned');
#	like($warning_message, qr/Test2/, 'Second warning was properly warned');
#};

done_testing;