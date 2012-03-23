package TCC::Perl;
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

1;

__END__

=head1 NAME

TCC::Perl - Enabling Perl's full C-API in your TCC compiler context

=head1 SYNOPSIS

 use TCC;
 
 # Declare the compiler context with the AV bindings:
 my $context= TCC->new(packages => '::Perl');
 
 # Or add them afterwards:
 my $context = TCC->new;
 $context->add_packages('::Perl');
 
 # Create a function that tells us how many arguments we sent:
 $context->code('Body') = q{
 	void test_func(AV * inputs, AV * outputs) {
 		printf("You sent %d arguments\n", av_len(inputs));
 	}
 };
 
 # Compile and call:
 $context->compile;
 $context->call_function('test_func', 1, 2, 3);

=head1 DESCRIPTION

This module provides access to the full Perl C API in your compiler context.
This is a very blunt tool, but it is guaranteed to always reflect the API of
whichever version of Perl you use to run your script. It is equivalent to
including the following in your C<Head> code section:

 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"

where it determines the path to your Perl's include directory during your
script's compile phase. On my machine, the resulting text of this pull-in is
equivalent to approximately 8,000 or 10,000 lines of I<real> code, depending on
how you define I<real> (as well as many blank lines), which is why I consider it
to be quite a blunt tool.

(What follows is what I *hope* happens, though it is not yet the reality.) This
great weight is the reason the TCC::Perl::* sub-modules exist. They pull in and
define only the exact code that you need.

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tcc at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TCC>.  I
will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TCC::Perl

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

Copyright 2012 Northwestern University

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut


