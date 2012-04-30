# A set of tests that ensure that TCC::Perl::Croak defers to TCC::Perl.

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;

use TCC;

### 1: Create a context with TCC::Perl::Croak
my $context = TCC->new('::Perl::Croak');
like($context->code('Head'), qr/TCC::Perl::Croak/, 'TCC::Perl::Croak installs itself');

### 2: Adding TCC::Perl removes the TCC::Perl::Croak stuff
$context->apply_packages('::Perl');
like($context->code('Head'), qr/TCC::Perl"/, 'TCC::Perl installs itself');
unlike($context->code('Head'), qr/TCC::Perl::Croak/
	, 'TCC::Perl::Croak uninstalls itself with TCC::Perl is there');

