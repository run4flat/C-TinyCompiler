package TCC::SV;
use strict;
use warnings;
use parent 'TCC::package';
use TCC::Typedefs;

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'TCC::SV', $VERSION;
}

sub apply {
	my (undef, $state) = @_;
	
	# Make sure we have the necessary typedefs:
	$state->apply_package('TCC::Typedefs');
	
	# Add function declarations and symbols:
	$state->code('Head') .= q{
		double SvNV (SV * sv);
		void sv_setNV (SV * sv, double val);
	};
}

sub apply_sumbols {
	my (undef, $state) = @_;
	_add_basic_SV_functions($state->{_state});
}

1;
