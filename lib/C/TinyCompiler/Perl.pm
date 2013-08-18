package C::TinyCompiler::Perl;
use strict;
use warnings;
use parent 'C::TinyCompiler::package';

# Find the CORE diretory:
my $core_dir;
foreach (@INC) {
	if (-d "$_/CORE/") {
		$core_dir = "$_/CORE/";
		last;
	}
}
die "Unable to locate Perl CORE directory!" unless $core_dir;

# Pull in the local includes:
use Config;
my @local_inc = grep {-d} split / /, $Config{locincpth};
# Add i386-linux-gnu, since that's causing trouble on my Ubuntu. I wish there
# were a better way to handle this. :-(
for (@local_inc, '/usr/include') {
	push @local_inc, "$_/i386-linux-gnu" if -d "$_/i386-linux-gnu";
}

sub apply {
	my (undef, $state) = @_;
	
	# Add Perl's CORE directory to the compiler's list of includes:
	$state->add_include_paths($core_dir, @local_inc);
	
	# Add function declarations and symbols:
	$state->code('Head') .= C::TinyCompiler::line_number(__LINE__) . q{
		#include "EXTERN.h"
		#include "perl.h"
		#include "XSUB.h"
		#line 1 "whatever comes after C::TinyCompiler::Perl"
	};
}

1;

__END__

=head1 NAME

C::TinyCompiler::Perl - Enabling Perl's full C-API in your C::TinyCompiler context

=head1 SYNOPSIS

 use C::TinyCompiler;
 
 # Declare the compiler context with the Perl bindings:
 my $context= C::TinyCompiler->new('::Perl');
 
 # Or add them afterwards:
 my $context = C::TinyCompiler->new;
 $context->apply_packages('::Perl');
 
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
weight is the motivation for the C::TinyCompiler::Perl::* sub-modules. They pull in and
define only the exact code that you need.

=head1 ERROR MESSAGES

This module may lead to some interesting error messages. Here's a reference.

=over

=item Unable to locate Perl CORE directory!

This compile-time error will indicate that C::TinyCompiler::Perl was not able to find the
CORE directory in your Perl libs. This is a big issue because the header files
that C::TinyCompiler::Perl wants to include in your compiler context can only be found in
this directory. If you run into this problem, it means you do not have your
Perl header files stored in a customary place. If you don't know how to fix
this, you should reach out to me or to the Perl community (i.e. PerlMonks) for
help.

=item whatever comes after C::TinyCompiler::Perl

If you see anything with this text in it, you have encountered an error
(probably a compile error) in code that you added to your compiler's Head
section after you added the C::TinyCompiler::Perl package. Check any and all code that you
added. Using L<C::TinyCompiler/line_numbers> may help narrow-down the errant line in your
code.

=back

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests at the project's main github page:
L<http://github.com/run4flat/perl-TCC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::TinyCompiler::Perl

You can also look for information at:

=over 4

=item * The Github issue tracker (report bugs here)

L<http://github.com/run4flat/perl-TCC/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/C-TinyCompiler>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/C-TinyCompiler>

=item * Search CPAN

L<http://p3rl.org/C::TinyCompiler>
L<http://search.cpan.org/dist/C-TinyCompiler/>

=back

=head1 LICENSE AND COPYRIGHT

Code copyright 2012 Northwestern University. Documentation copyright 2012-2013
David Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut


