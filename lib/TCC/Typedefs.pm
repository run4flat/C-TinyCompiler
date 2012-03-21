package TCC::Typedefs;
use strict;
use warnings;
use parent 'TCC::package';

sub apply {
	my (undef, $state) = @_;
	$state->code('Head') .= q{
		typedef void SV;
		typedef void AV;
		typedef void CV;
		typedef void HV;
		typedef void HE;
	};
}

1;
