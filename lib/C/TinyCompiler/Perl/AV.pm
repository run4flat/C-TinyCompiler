package C::TinyCompiler::Perl::AV;
use strict;
use warnings;
use base 'C::TinyCompiler::package';

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'C::TinyCompiler::Perl::AV', $VERSION;
}

sub apply {
	my (undef, $state) = @_;
	
	# Make sure we have the necessary typedefs:
	$state->apply_packages('C::TinyCompiler::Perl::Typedefs');
	
	# Add function declarations and symbols:
	$state->code('Head') .= q{
		void av_clear (AV * array);
		int av_len (AV * av);
		SV ** av_fetch (AV * av, int key, int lval);
	};
}

# Retrieve the symbol pointers only once:
my $symbols = get_symbol_ptrs();

sub apply_symbols {
	my (undef, $state) = @_;
	$state->add_symbols(%$symbols);
}

1;

__END__

=head1 NAME

C::TinyCompiler::Perl::AV - Perl's array C-API

=head1 STILL UNDER CONSTRUCTION

This code has not seen much attention and has neither been carefully reviewed
nor tested. It may not even be C<use>able. You have been warned.

=head1 SYNOPSIS

 use C::TinyCompiler;
 
 # Declare the compiler context with the AV bindings:
 my $context= C::TinyCompiler->new(packages => '::Perl::AV');
 
 # Or add them afterwards:
 my $context = C::TinyCompiler->new;
 $context->add_packages('::Perl::AV');
 
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

This module provides various Perl array manipulate functions to the compiler
context. Eventually it will contain options so that you can specify which parts
of the API you want, but for now it comes in one big bunch (or as much of it as
I have packaged thus far).

Like other C::TinyCompiler packages, you never use this module directly. Rather, you
add it to your compiler context in the constructor or with the function
L<C::TinyCompiler/apply_packages>.

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

Please report any bugs or feature requests at the project's main github page:
L<http://github.com/run4flat/perl-TCC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::TinyCompiler::Perl::AV

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

Code Copyright 2011-2012 Northwestern University. Documentation copyright
2011-2013 David Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
