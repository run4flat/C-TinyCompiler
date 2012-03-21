package TCC::package;

use strict;
use warnings;

sub get_packages {
	my $package_list;
	if (@_ > 0) {
		$package_list = shift;
	}
	else {
		$package_list = (caller(1))[10]->{TCC_packages};
	}
	$package_list ||= '';
	return split /[|]/, $package_list;
}

sub apply {
	# empty apply
}

sub apply_symbols {
	# empty apply_symbols
}

sub import {
	my $module = shift;
	# Build a hash with keys as currently used package names:
	my %packages = map {$_ => 1} get_packages($^H{TCC_packages});
	# Add this package:
	$packages{$module} = 1;
	# Reassemble into the package list:
	$^H{TCC_packages} = join('|', keys %packages);
}

sub unimport {
	my $module = shift;
	# Build a hash with keys as currently used package names:
	my %packages = map {$_ => 1} get_packages($^H{TCC_packages});
	# Remove this package:
	delete $packages{$module};
	# Reassemble into the package list:
	$^H{TCC_packages} = join('|', keys %packages);
}

1;
