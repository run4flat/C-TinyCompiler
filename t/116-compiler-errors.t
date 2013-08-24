#!perl
# A test to make sure that C::TinyCompiler handles compiler errors and
# warnings, and differentiates between the two.

use 5.006;
use strict;
use warnings;
use Test::More;
use Test::Exception;
use C::TinyCompiler;

## Preprocessor error ##
my $context = C::TinyCompiler->new;
$context->code('Body') .= q{
	#error "This is only a test"
};
throws_ok { $context->compile } qr/This is only a test/
	=> 'Issues an exception when it encounters a preprocessor';

## Typo/compile-time error ##
my $context = C::TinyCompiler->new;
$context->code('Body') .= q{
	void some_func() {
		/* No trailing semicolon, should throw error */
		int bad_declaration = 5
	}
};
dies_ok { $context->compile } 'Compile-time error issues an exception';


done_testing;