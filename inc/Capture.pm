# My tiny capture library, used to test the simplest of TCC programs.

use strict;
use warnings;
use File::Temp qw(tempfile);

# Used to get the correct perl interpreter
use Module::Build;

sub Capture::it {
	my $code = shift;
	my ($source_fh, $source_filename) = tempfile;
	
	# Write the code to the source file:
	print $source_fh $code;
	close $source_fh;
	
	# Get the correct perl interpreter:
	my $build = Module::Build->current;
	my $perl = $build->find_perl_interpreter;
	
	# Run it!
	my $results = `$perl -Mblib $source_filename 2>&1`;
	
	# clean up the file and return the results
	unlink $source_filename;
	return $results;
}

1;
