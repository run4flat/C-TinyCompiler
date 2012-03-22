package TCC::AV;
use strict;
use warnings;
use base 'TCC::package';

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'TCC::AV', $VERSION;
}

sub apply {
	my (undef, $state) = @_;
	
	# Make sure we have the necessary typedefs:
	$state->apply_packages('TCC::Typedefs');
	
	# Add function declarations and symbols:
	$state->code('Head') .= q{
		int av_len (AV * av);
		SV ** av_fetch (AV * av, int key, int lval);
	};
}

# Retrieve the symbol pointers only once:
my $symbols = get_symbol_ptrs();

sub apply_symbols {
	my (undef, $state) = @_;
	$state->add_symbols(%$symbols);
}

1;
