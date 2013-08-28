#!/usr/bin/perl
use strict;
use warnings;

# Stash the unstaged modifications:
`git stash save --keep-index`;

my $to_return = 0;

# Did I remember to touch the Changes file?
my $touched_files = `git status --porcelain`;
if ($touched_files !~ /Changes/) {
	$|++;
	print "It looks like you didn't update the Changes file. Should I continue (y/n)? ";
	open STDIN, '<', '/dev/tty';
	my $response = <>;
	
	$to_return = 1 if $response eq 'y';
}

# Restore the stash and return the result
`git reset --hard`;
`git stash pop --index`;

exit($to_return);
