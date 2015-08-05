# A test of the Perl API

use 5.006;
use strict;
use warnings;
use Test::More;

use C::TinyCompiler;

### 1: Create a context with C::TinyCompiler::Perl
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
is($my_sum->(\1, 2), 3, 'Provides a viable function that works correctly');


### Can I modify an SV that's been passed in?
$context = C::TinyCompiler->new('::Perl', '::Callable');
$context->code('Body') = q{
	C::TinyCompiler::Callable
	void my_set_IV (SV * a, int b) {
		sv_setiv(a, b);
	}
};
$context->compile;
my $my_set = eval { $context->get_callable_subref('my_set_IV') };
is($@, '', 'get_callable_subref does not croak for a valid function declaration with ints and SV');
my $to_set;
$my_set->(\$to_set, 10);
is($to_set, 10, 'Can modify SVs sent as function arguments');

done_testing;
