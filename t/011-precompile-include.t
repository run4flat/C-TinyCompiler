#!perl -T
# A test to check that include behavior works correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 4;

use C::TinyCompiler;
my $context = C::TinyCompiler->new;

############## normal inclusion tests: 2
eval {$context->add_include_paths('.')};
is($@, '', "Add '.' (i.e. existing path) to include paths");
eval {$context->add_include_paths('random-does-not-exist')};
is($@, '', '... and a non-existent path');

############## system inclusion tests: 2
eval {$context->add_sysinclude_paths('.')};
is($@, '', "Add '.' (i.e. existing path) to include syspaths");
eval {$context->add_sysinclude_paths('random-does-not-exist')};
is($@, '', '... and a non-existent path');
