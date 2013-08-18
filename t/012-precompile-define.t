#!perl -T
# Tests to check that preprocessor definitions work. These are the unit tests
# and they don't really test things out properly. I can't do that until I have
# a way to compile and execute code, which these tests do not assume.

use 5.006;
use strict;
use warnings;
use Test::More tests => 13;

use C::TinyCompiler;
my $context = C::TinyCompiler->new;

############## simple define behavior: 6
eval {$context->define('my_symbol')};
is($@, '', 'Defining a symbol does not croak')
	or diag("Error: $@");
ok($context->is_defined('my_symbol'), 'Symbol gets stored in local hash')
	or diag('is_defined returned false when it should have returned true');
is($context->definition_for('my_symbol'), '',
	'Default symbol definition is empty string')
	or diag('Symbol should have been the empty string but it was '
		. $context->definition_for('my_symbol'));

eval {
	# Suppress warnings and redefine the symbol:
	local $SIG{__WARN__} = sub {};
	$context->define('my_symbol', 'value');
};
	
is($@, '', 'Redefinition is ok')
	or diag("Error: $@");
ok($context->is_defined('my_symbol'), 'Redefinition still exists in hash')
	or diag('is_defined returned false after redefinition');
is($context->definition_for('my_symbol'), 'value',
	'Redfining a symbol properly stores the value')
	or diag('After redefinition, value was incorrectly set as '
		. $context->definition_for('my_symbol'));


############## warning and croaking behavior: 3
{
	my $got_warnings = 0;
	local $SIG{__WARN__} = sub {
		$got_warnings++;
	};
	eval {$context->define('my_symbol', 'value2')};
	is($got_warnings, 1, 'Default behavior emits a warnings');
}

{
	my $got_warnings = 0;
	local $SIG{__WARN__} = sub {
		$got_warnings++;
	};
	no warnings 'C::TinyCompiler';
	eval {$context->define('my_symbol', 'value4')};
	is($@, '', 'Redefinition under "no warnings qw(C::TinyCompiler)" does not croak');
	is($got_warnings, 0, 'Redefinition under "no warnings qw(C::TinyCompiler)" does not warn');
}

############## undefining: 4
eval {$context->undefine('my_symbol')};
is($@, '', 'Undefining an existing macro does not croak')
	or diag($@);
ok(!$context->is_defined('my_symbol'), 'Symbol is removed from the local cache');

eval {$context->undefine('foo_does_not_exist')};
is($@, '', 'Undefining a non-existent macro does not croak')
	or diag($@);
ok(!$context->is_defined('foo_does_not_exist')
	, 'Undefining non-existent symbol does not add it to the local cache');

