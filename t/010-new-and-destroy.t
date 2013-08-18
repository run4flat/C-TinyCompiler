#!perl -T
# A test to check that new and destroy work

use 5.006;
use strict;
use warnings;
use Test::More tests => 2;

use C::TinyCompiler;

my $context = eval { C::TinyCompiler->new };
isnt($context, undef, 'C::TinyCompiler->new') or diag ($@);

eval { $context = undef };
is($@, '', 'Destruction') or diag($@);
