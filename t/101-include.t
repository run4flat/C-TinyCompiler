#!perl -T
# A test to check that include behavior works correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 4;

use TCC;
my $context = TCC->new;

############## normal inclusion tests: 2
eval {$context->add_include_path('.')};
is($@, '', "Adding '.' should always works");
eval {$context->add_include_path('random-does-not-exist')};
isnt($@, '', 'Adding a non-existent path croaks');

############## system inclusion tests: 2
eval {$context->add_sysinclude_path('.')};
is($@, '', "Adding '.' should always works");
eval {$context->add_sysinclude_path('random-does-not-exist')};
isnt($@, '', 'Adding a non-existent path croaks');
