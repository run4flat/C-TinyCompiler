#!perl

use 5.006;
use strict;
use warnings;
use Test::More tests => 4;

use TCC;

### 1: Load test

BEGIN {
    use_ok( 'TCC::Perl::Croak' ) or BAIL_OUT('Unable to load TCC::Perl::Croak!');
}

### 3: Create a function that simply croaks
my $return = eval {
	my $context = TCC->new('::Perl::Croak');
	$context->code('Body') = q{
		void test_func(void) {
			croak("This is only a test");
		}
	};
	$context->compile;
	$context->call_void_function('test_func');
	1;
};

isnt($return, 1, 'Code croaks, as expected');
isnt($@, '', 'Code sets $@');
like($@, qr/This is only a test/, 'Croaks from the C function');


