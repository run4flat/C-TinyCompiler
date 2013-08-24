#!perl
# A test to make sure that C::TinyCompiler handles compiler errors and
# warnings, and differentiates between the two.

use 5.006;
use strict;
use warnings;
use Test::More;
use Test::Warnings;
use C::TinyCompiler;

my $context = C::TinyCompiler->new;
$context->code('Body') .= q{
	#warning "This is only a test"
};

my $warning_message = eval { warning { $context->compile } };
diag("Got warning message $warning_message");

# No dying:
is($@, '', 'Compiler warning did not cause compiler to croak');
like($warning_message, /This is only a test/, 'Warning text was properly warned');

done_testing;