#!perl -T
# A test to check that the code setters/getters work correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 29;

use C::TinyCompiler;
my $context = C::TinyCompiler->new;

############## simple addition and retrieval tests: 9 x 3 = 27
for my $location (qw(Head Body Foot)) {
	my $text = eval {$context->code($location) };
	is($@, '', "Getting code from $location before setting anything does not croak");
	is($text, '', "Initial $location text is the empty string");
	eval {$context->code($location) = $location};
	is($@, '', "Adding code to $location works fine");
	$text = eval {$context->code($location)};
	is($@, '', "Getting code from $location after setting does not croak");
	is($text, $location, "Strings are properly stored in $location");
	
	# Also check capitalization
	my $mod_location = lc $location;
	$text = eval {$context->code($mod_location)};
	is($@, '', "Getting code from $mod_location does not croak");
	is($text, $location, "Strings are properly stored in $mod_location");
	
	$mod_location = uc $location;
	$text = eval {$context->code($mod_location)};
	is($@, '', "Getting code from $mod_location does not croak");
	is($text, $location, "Strings are properly stored in $mod_location");
}

############## invalid locations: 2
eval {$context->code('foo')};
isnt($@, '', "Retrieving code from location 'foo' croaks");
like($@, qr/Unknown location/, "Croaking message is descriptive");
