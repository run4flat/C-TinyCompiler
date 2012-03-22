package TCC::SV;
use strict;
use warnings;
use parent 'TCC::package';

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'TCC::SV', $VERSION;
}

sub apply {
	my (undef, $state) = @_;
	
	# Make sure we have the necessary typedefs:
	$state->apply_packages('TCC::Typedefs');
	
	# Add function declarations and symbols:
	$state->code('Head') .= q{
		double SvNV (SV * sv);
		int SvIV(SV * sv);
		void sv_setNV (SV * sv, double val);
	};
}

# Retrieve the symbol pointers only once:
my $symbols = get_symbol_ptrs();

sub apply_symbols {
	my (undef, $state) = @_;
	$state->add_symbols(%$symbols);
}

1;
