#!perl -T
# A test to check that include behavior works correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 4;

use TCC;
my $context = TCC->new;

############## normal inclusion tests: 2
eval {$context->add_include_paths('.')};
is($@, '', "Adding '.' should always work");
eval {$context->add_include_paths('random-does-not-exist')};
isnt($@, '', 'Adding a non-existent path croaks');

############## system inclusion tests: 2
eval {$context->add_sysinclude_paths('.')};
is($@, '', "Adding '.' should always work");
eval {$context->add_sysinclude_paths('random-does-not-exist')};
isnt($@, '', 'Adding a non-existent path croaks');
