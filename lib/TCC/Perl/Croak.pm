package TCC::Perl::Croak;
use strict;
use warnings;
use parent 'TCC::package';

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'TCC::Perl::Croak', $VERSION;
}

sub apply {
	my (undef, $state) = @_;
	
	# Add function declarations and symbols:
	$state->code('Head') .= TCC::line_number(__LINE__) . q{
		/* BEGIN TCC::Perl::Croak */
		#include <stdarg.h>
		void croak(const char *pat, ...);
		void warn(const char *pat, ...);
		void vcroak(const char *pat, va_list *args);
		void vwarn(const char *pat, va_list *args);
		#line 1 "whatever comes after TCC::Perl::Croak"
	};
}

sub conflicts_with {
	my (undef, $state, @packages) = @_;
	
	# If Perl is not among the listed packages, we have no conflicts
	return 0 unless grep { $_ eq 'TCC::Perl' } @packages;
	
	my $package = __PACKAGE__;
	
	# If we're here, we know that Perl *is* among the @packages, so we have a
	# conflict. If this package has not been applied, then we can simply return
	# a true value, thus registering it as blocked.
	return 1 unless $state->is_package_applied($package);
	
	# We can only reach this line of code if this package *has* been applied and
	# we're about to apply TCC::Perl. As such, remove our code from the header
	# and block our own package.
	$state->code('Header') =~ s{/\* BEGIN $package .*"whatever comes after $package"}{}s;
	$state->block_package($package);
	
	# Don't register a conflict with TCC::Perl; it has been resolved on our end :-)
	return 0;
}

sub apply_symbols {
	my (undef, $state) = @_;
	_apply_symbols($state);
}

1;

__END__

=head1 NAME

TCC::Perl::Croak - A light-weight interface to Perl's croak and warn

=head1 SYNOPSIS

 use TCC;
 
 # Declare the compiler context with the AV bindings:
 my $context= TCC->new(packages => '::Perl::Croak');
 
 # Create a rather antisocial function:
 $context->code('Body') = q{
     void dont_call(void) {
         croak("I told you not to call!");
     }
 };
 
 # Compile and call:
 $context->compile;
 eval {
     $context->call_function(dont_call);
     1
 } or do {
     print "Got error $@\n";
 };

=head1 DESCRIPTION

This module provides Perl's C interface to both the traditional and variadic
forms of warn and croak. These allow you to write defensive C code without
needing the full Perl C api to do it.

various Perl array manipulate functions to the compiler
context. Eventually it will contain options so that you can specify which parts
of the API you want, but for now it comes in one big bunch (or as much of it as
I have packaged thus far).

Like other TCC packages, you never use this module directly. Rather, you
add it to your compiler context in the constructor or with the function
L<TCC/apply_packages>.

Documentation for all of these functions can be found at L<perlapi>, so I will
only give their names and signatures here for reference (and possibly a few
notes if I deem them to be helpful).

=over

=item av_clear

 void av_clear (AV * array)

=item av_len

 int av_len (AV * array)

=item av_fetch

 SV ** av_fetch (AV * array, int key, int lval)

Fetches the requested item from the array, creating it if necessary. The usage
is descriped in L<perlapi>. I simply wish to point out that in my experience,
the only time the returned pointer to the SV is only null is when I try to
retrieve a non-existent array element B<not> in lvalue context. (I suspect that
it may also return null in lvalue context if Perl is unable to allocate the
contiguous memory for C<key> elements, but I have not confirmed that.) The point
is that you B<ought to> check that the returned pointer is non-null before
dereferencing it.

=back

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tcc at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TCC>.  I
will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TCC::Perl::AV

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=TCC>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/TCC>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/TCC>

=item * Search CPAN

L<http://search.cpan.org/dist/TCC/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011, 2012 Northwestern University

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
