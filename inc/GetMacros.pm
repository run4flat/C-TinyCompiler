use strict;
use warnings;

# This is a module that provides a means for determining the following:
# 1) Is a C "function" actually a macro?
# 2) What is the full substitution for a C macro?
#
# In this way, I can query Perl's API at build time and figure out exactly what
# I need for every piece of information I need for every single function.

use File::Temp qw(tempfile);

# Get the CORE diretory:
my $core_dir;
foreach (@INC) {
	if (-d "$_/CORE/") {
		$core_dir = "$_/CORE/";
		last;
	}
}

sub get_macro_definitions {
	my ($fh, $filename) = tempfile();

	# Add the header:

	print $fh q(

	#include "EXTERN.h"
	#include "perl.h"
	#include "XSUB.h"

	);

	# Add each symbol:
	my $delimiter = '_____';
	for my $symbol (@_) {
		print $fh <<SYMBOL;
$delimiter$symbol
$symbol
SYMBOL
	}

	close $fh;

	# Now we're ready to run the preprocessor

	open my $results_fh, '-|', "tcc -E -I$core_dir $filename";

	#open my $out_fh, '>', 'details';

	# Rip through the file until we found the first marker:
	my $current_macro;
	LINE: while(my $line = <$results_fh>) {
		if ($line =~ /^$delimiter(.+)$/) {
			$current_macro = $1;
			last LINE;
		}
		# working here - remove eventually
	#	next if index($line, '#') == 0 or 
	#		$line =~ /^\s*$/;
	#	print $out_fh $line;
	}

	die "Could not find any macros; see $filename\n" unless defined $current_macro;

	# Process everything, looking for definitions and also for non-definitions,
	# which means the symbol is not a macro but an actual symbol.
	my %macros;
	my @function_defs;
	LINE: while(my $line = <$results_fh>) {
		chomp $line;
		if ($line =~ /^$delimiter(.+)$/) {
			$current_macro = $1;
			next LINE;
		}
		
		if ($line eq $current_macro) {
			# Means it's not a macro at all, but a bonafide symbol:
			push @function_defs, $current_macro;
		}
		else {
			$macros{$current_macro} .= $line;
		}
	}
	
	# Run through all the functions and extract the official definitions:
	
	
	unlink $filename;
	return (\@function_defs, \%macros);
}

