package TCC::AV;
use strict;
use warnings;
use base 'TCC::package';
use TCC::Typedefs;

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'TCC::AV', $VERSION;
}

sub apply {
	my (undef, $state) = @_;
	
	# Make sure we have the necessary typedefs:
	$state->apply_package('TCC::Typedefs');
	
	# Add function declarations and symbols:
	$state->code('Head') .= q{
		int av_len (AV * av);
		SV ** av_fetch (AV * av, int key, int lval);
	};
}

sub apply_symbols {
	my (undef, $state) = @_;
warn "Applyg av symbols\n";
	_add_basic_AV_functions($state->{_state});
}

1;
