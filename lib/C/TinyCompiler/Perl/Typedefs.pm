package C::TinyCompiler::Perl::Typedefs;
use strict;
use warnings;
use parent 'C::TinyCompiler::package';

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
