# A set of tests that ensure that C::TinyCompiler::Perl::Croak defers to C::TinyCompiler::Perl.

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;

use C::TinyCompiler;

### 1: Create a context with C::TinyCompiler::Perl::Croak
my $context = C::TinyCompiler->new('::Perl::Croak');
like($context->code('Head'), qr/C::TinyCompiler::Perl::Croak/, 'C::TinyCompiler::Perl::Croak installs itself');

### 2: Adding C::TinyCompiler::Perl removes the C::TinyCompiler::Perl::Croak stuff
$context->apply_packages('::Perl');
like($context->code('Head'), qr/C::TinyCompiler::Perl"/, 'C::TinyCompiler::Perl installs itself');
unlike($context->code('Head'), qr/C::TinyCompiler::Perl::Croak/
	, 'C::TinyCompiler::Perl::Croak uninstalls itself with C::TinyCompiler::Perl is there');

