# A test of the Perl API

use 5.006;
use strict;
use warnings;
use Test::More tests => 2;

use C::TinyCompiler;

### 1: Create a context with C::TinyCompiler::Perl::Croak
my $context = C::TinyCompiler->new('::Perl', '::Callable');
$context->code('Body') = q{
	C::TinyCompiler::Callable
	int my_sum (SV * a, int b) {
		return SvIV(a) + b;
	}
};
$context->compile;
my $my_sum = eval { $context->get_callable_subref('my_sum') };
is($@, '', 'get_callable_subref does not croak for a valid function declaration with ints and SV');
is($my_sum->(1, 2), 3, 'Provides a viable function that works correctly');


