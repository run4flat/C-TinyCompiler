#!perl -T
# A test to check that new and destroy work

use 5.006;
use strict;
use warnings;
use Test::More tests => 2;

use TCC;

my $context = eval { TCC->new };
isnt($context, undef, 'TCC->new') or diag ($@);

eval { $context = undef };
is($@, '', 'Destruction') or diag($@);
