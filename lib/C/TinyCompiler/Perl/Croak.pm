package C::TinyCompiler::Perl::Croak;
use strict;
use warnings;
use parent 'C::TinyCompiler::package';

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'C::TinyCompiler::Perl::Croak', $VERSION;
}

sub apply {
	my (undef, $state) = @_;
	
	# Add function declarations and symbols:
	$state->code('Head') .= C::TinyCompiler::line_number(__LINE__) . q{
		/* BEGIN C::TinyCompiler::Perl::Croak */
		#include <stdarg.h>
		void croak(const char *pat, ...);
		void warn(const char *pat, ...);
		void vcroak(const char *pat, va_list *args);
		void vwarn(const char *pat, va_list *args);
		#line 1 "whatever comes after C::TinyCompiler::Perl::Croak"
	};
}

# Retrieve the symbol pointers only once:
my $symbols = get_symbol_ptrs();

sub apply_symbols {
	my (undef, $state) = @_;
	$state->add_symbols(%$symbols);
}

sub conflicts_with {
	my ($package, $state, @packages) = @_;
	
	# If Perl is not among the listed packages, we have no conflicts
	return 0 unless grep { $_ eq 'C::TinyCompiler::Perl' } @packages;
	
	# If we're here, we know that Perl *is* among the @packages, so we have a
	# conflict. If this package has not been applied, then we can simply return
	# a true value, thus registering it as blocked.
	return 1 unless $state->is_package_applied($package);
	
	# We can only reach this line of code if this package *has* been applied and
	# we're about to apply C::TinyCompiler::Perl. As such, remove our code from the header
	# and block our own package.
	$state->code('Head') =~ s{/\* BEGIN $package .*"whatever comes after $package"}{}s;
	$state->block_package($package);
	
	# Don't register a conflict with C::TinyCompiler::Perl; it has been resolved on our end :-)
	return 0;
}

1;

__END__

=head1 NAME

C::TinyCompiler::Perl::Croak - A light-weight interface to Perl's croak and warn

=head1 SYNOPSIS

 use C::TinyCompiler;
 
 # Declare the compiler context with the AV bindings:
 my $context= C::TinyCompiler->new(packages => '::Perl::Croak');
 
 # Create a rather antisocial function:
 $context->code('Body') = q{
     void dont_call(void) {
         croak("I told you not to call!");
     }
 };
 
 # Compile and call:
 $context->compile;
 eval {
     $context->call_function('dont_call');
     1
 } or do {
     print "Got error $@\n";
 };

=head1 DESCRIPTION

This module provides Perl's C interface to both the traditional and variadic
forms of warn and croak. These allow you to write defensive C code without
needing the full Perl C api to do it.

Like other C::TinyCompiler packages, you never use this module directly. Rather, you
add it to your compiler context in the constructor or with the function
L<C::TinyCompiler/apply_packages>.

You can find documentation for these functions at L<perlapi>. However, the
discussion of the variadic forms of is not terribly illuminating, so I provide
a few examples below.

=over

=item *

 void croak(const char *pat, ...)

Provides printf-style croaking that integrates with Perl's C<die> and other
error handling. For example:

 ...
 /* Allocate 10 elements */
 int n_elements = 10;
 double * my_array = malloc(n_elements * sizeof(double));
 if (my_array == 0) {
     /* Clean up anything else */
     ...
     /* Croak with error message */
     croak("Unable to allocate double array with %d elements", n_elements);
 }
 /* otherwise continue */

Since this uses Perl's error handling, this croak can be captured in your Perl
code with an C<eval> block.

The croak performs a C<lngjmp>, so you will B<never get control back>. That
means that if you allocated some memory dynamically, you must clean up that
memory before croaking or it will leak.

=item *

 void warn(const char *pat, ...);

Provides printf-style warning that integrates with Perl's C<warn> function:

 ...
 if (my_intput < 0) {
     warn("Input was negative (%f) but it must be strictly positive; using zero", my_input);
     my_input = 0.0;
 }

=item *

 void vcroak(const char *pat, va_list *args);

A variadic version of C<croak>. This is useful when you create your own variadic
function. For example, if you want to create your own croak that cleans up
memory for you, you could try something like this:

 void my_croak (void ** to_free, int N_to_free, const char * pat, ...) {
     /* Free any allocated memory */
     while (N_to_free > 0) free(to_free[--N_to_free]);
     
     /* Now throw the croak */
     va_list args;
     vcroak(pat, &args);
 }
 
 ...
 
 void my_func (int arg1, int arg2) {
     void * my_arrays [10];
     /* Set them all to zero */
     int i;
     for (i = 0; i < 10; my_arrays[i++] = 0);
     
     ... allocate some memory, add the pointers to to_free ...
     
     if (foo > upper_limit) {
         my_croak(my_arrays, 10, "Trouble! foo (%f) is greater than the upper limit (%f)!"
             , foo, upper_limit);
     }
 }

(Note that L<C::TinyCompiler::StretchyBuffers> is probably the easiest way to handle such a
dynamic list of arrays that need to be freed.)

Just to be crystal clear, if you use this to wrap your variadic function, you
must obtain your C<va_list> like so:

 void my_croak(char * pat, ...) {
     ...
     
     va_list args;
     vcroak(pat, &args);
 }

=item *

 void vwarn(const char *pat, va_list *args);

A variadic version of C<warn>. See the discussion on C<vcroak> above.

=back

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests at the project's main github page:
L<http://github.com/run4flat/perl-TCC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::TinyCompiler::Perl::Croak

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

Code copyright 2011-2012 Northwestern University. Documentation copyright
2011-2013 David Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
