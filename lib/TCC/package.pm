package TCC::package;

use strict;
use warnings;

sub get_packages {
	my $level = shift // 0;
	my $hinthash = (caller($level))[10];
	
	return () unless $hinthash->{TCC_packages};
	return split /[|]/, $hinthash->{TCC_packages}
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
	my %packages = map {$_ => 1} get_packages;
	# Add this package:
	$packages{$module} = 1;
	# Reassemble into the package list:
	$^H{TCC_packages} = join('|', keys %packages);
}

sub unimport {
	my $module = shift;
	# Build a hash with keys as currently used package names:
	my %packages = map {$_ => 1} get_packages;
	# Remove this package:
	delete $packages{$module};
	# Reassemble into the package list:
	$^H{TCC_packages} = join('|', keys %packages);
}

1;
