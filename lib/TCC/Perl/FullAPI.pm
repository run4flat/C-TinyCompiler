package TCC::Perl::FullAPI;
use strict;
use warnings;
use parent 'TCC::package';

# Find the CORE diretory:
my $core_dir;
foreach (@INC) {
	if (-d "$_/CORE/") {
		$core_dir = "$_/CORE/";
		last;
	}
}

die "Unable to locate Perl CORE directory!" unless $core_dir;

sub apply {
	my (undef, $state) = @_;
	
	# Add Perl's CORE directory to the compiler's list of includes:
	$state->add_include_path($core_dir);
	
	# Add function declarations and symbols:
	$state->code('Head') .= q{
		#include "EXTERN.h"
		#include "perl.h"
		#include "XSUB.h"
	};
}



