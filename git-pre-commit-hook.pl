#!/usr/bin/perl
use strict;
use warnings;

# Stash the unstaged modifications:
`git stash save --keep-index`;

# Assume good unless we find a problem
my $to_return = 0;

# Did I remember to touch the Changes file?
my $touched_files = `git status --porcelain`;
if ($touched_files !~ /Changes/) {
	# Assume bad unless the user overrides
	$to_return = 1;
	$|++;
	print "It looks like you didn't update the Changes file. Should I continue (y/n)? ";
	open STDIN, '<', '/dev/tty';
	my $response = <>;
	
	$to_return = 0 if $response =~ 'y';
}

# Restore the stash and return the result
`git reset --hard`;
`git stash pop --index`;

exit($to_return);
