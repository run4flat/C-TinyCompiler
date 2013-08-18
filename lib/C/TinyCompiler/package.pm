package C::TinyCompiler::package;

use strict;
use warnings;

sub get_packages {
	my $package_list;
	if (@_ > 0) {
		$package_list = shift;
	}
	else {
		my $hashref = (caller(1))[10];
		$package_list = $hashref->{C_TinyCompiler_packages} if defined $hashref;
	}
	$package_list ||= '';
	return split /[|]/, $package_list;
}

# Args:
#  * $package_name
#  * $compiler_state
#  * @options
sub apply {
	# empty apply
}

# Args:
#  * $package_name
#  * $compiler_state
#  * @other_packages
sub conflicts_with {
	# doesn't conflict with anything
	0;
}

# Args:
#  * $package_name
#  * $compiler_state
#  * @options
sub apply_symbols {
	# empty apply_symbols
}

# Args:
#  * $package_name
#  * $compiler_state
#  * @options
sub preprocess {
	# No preprocessing
}

sub import {
	my $module = shift;
	# Build a hash with keys as currently used package names:
	my %packages = map {$_ => 1} get_packages($^H{C_TinyCompiler_packages});
	# Add this package:
	$packages{$module} = 1;
	# Reassemble into the package list:
	$^H{C_TinyCompiler_packages} = join('|', keys %packages);
}

sub unimport {
	my $module = shift;
	# Build a hash with keys as currently used package names:
	my %packages = map {$_ => 1} get_packages($^H{C_TinyCompiler_packages});
	# Remove this package:
	delete $packages{$module};
	# Reassemble into the package list:
	$^H{C_TinyCompiler_packages} = join('|', keys %packages);
}

1;

__END__

=head1 NAME

C::TinyCompiler::package - base module for C::TinyCompiler packages

=head1 SYNOPSIS

Here's a skeleton module for something that is meant to be a drop-in,
ostensibly light-weight replacement for some big package called (generically)
C::TinyCompiler::BigPackage.

 package My::C::TinyCompiler::BigPackage;
 use parent 'C::TinyCompiler::package';
 
 ### Overload the following, as appropriate ###
 
 # Called as soon as the package is applied:
 sub apply {
     my ($package, $compiler_state, @options) = @_;
     
     # Add to the Head section
     $compiler_state->code('Head') .= C::TinyCompiler::line_number(__LINE__) . q{
         /* BEGIN My::C::TinyCompiler::BigPackage Head */
         void my_func(void);
         #line 1 "whatever comes after My::C::TinyCompiler::BigPackage in the Head"
     };
     
     # Add to the code section
     $compiler_state->code('Body') .= C::TinyCompiler::line_number(__LINE__) . q{
         /* BEGIN My::C::TinyCompiler::BigPackage Body */
         void my_func(void) {
             printf("You called my_func!");
         }
         #line 1 "whatever comes after My::C::TinyCompiler::BigPackage in the Body"
     };
 }
 
 # Check for known bad interactions and (hopefully) respond gracefully
 sub conflicts_with {
     my ($package, $state, @packages) = @_;
     
     # Can't respond gracefully here:
     croak('My::C::TinyCompiler::BigPackage cannot be used in the same context as C::TinyCompiler::Foo')
         if (grep {$_ eq 'C::TinyCompiler::Foo'} @packages);
     
     # Otherwise, we only conflict with C::TinyCompiler::BigPackage, so return unless that's
     # present
     return 0 unless grep {$_ eq 'C::TinyCompiler::BigPackage'} @packages;
     
     # If this package is being installed, it won't yet be registered as
     # applied; returning 1 (conflicting) will prevent it from being applied
     return 1 unless $state->is_package_applied($package);
     
     # If we're here, we can conclude that (1) this package has been applied and
     # (2) C::TinyCompiler::BigPackage is about to be applied. Retract this package and
     # return 0, indicating that we have not problem with C::TinyCompiler::BigPackage:
     $state->code('Head')
         =~ s{/\* BEGIN $package Head.*"whatever comes after $package in the Head"}{}s;
     $state->code('Body')
         =~ s{/\* BEGIN $package Body.*"whatever comes after $package in the Body"}{}s;
     $state->block_package($package);
     
     return 0;
 }
 
 # If you load any shared libraries, this is your chance to add those
 # functions to the compiler state:
 sub apply_symbols {
     my ($package, $state, @options) = @_;
     
     # add_symbols expects symbol_name => pointer pairs
     $state->add_symbols($package->get_my_symbols());
 }
 
 # C-code source filtering, anyone? Applied after the C preprocessor
 # itself has run.
 sub preprocess {
     my ($package, $state, @options) = @_;
     $state->code('Body') =~ s/foo/bar/g;
 }


=head1 DESCRIPTION

C::TinyCompiler Packages provide a means to easily integrate C code and libraries into a
compiler context. They are akin to Perl modules, although applying them to a
compiler state is a bit different compared to saying C<use My::Module> in Perl.
The most important similarity (in my mind) is that you can request a package
multiple times without fear of trouble: each package is applied to a compiler
context only once.

One of the first differences is that each package is asked if it conflicts with
other packages that have been applied or are being applied. Although
incompatibilities between packages should not arise very often, this mechanism
provides a means for gracefully handling known conflicts between packages.

Another difference is that all packages are applied to the entire compiler
context. The compiler context has no notion of lexical packages. (libtcc itself
supports the notion of compiling multiple strings, much like compiling multiple
files, so it may be possible to get lexical scoping of some sort using this
mechanism. Patches welcome! :-)

Generally speaking, packages can accomplish these basic tasks:

=over

=item Load libraries, supply headers, add symbols

If you want to interface an external library to a C::TinyCompiler context, you can use a
package to dynamically load that library, add function declarations to the
Head section, and add function pointers to the compiler's symbol table.

=item Supply useful functions or constants

If you have a small but useful C library that is too small to distribute as an
independent shared library, you can create a C::TinyCompiler package to add the function
declarations and any preprocessor macros to the Head section, and the
definitions to the Body section, much like L<C::TinyCompiler::StretchyBuffer>. Or, you could
scan the source code and generate functions dynamically based on content found
in the code, as is done with C<C::TinyCompiler::Callable>.

=item Selectively override another package's behavior

All code sections can be directly manipulated, so it is possible to use the
C<preprocess> method to redefine functions or rename function calls for
selective overriding after having applied a package.

=item Apply general source filtering

The C<preprocess> method allows for general text manipulation, so you can use
it for generic source filtering. If you like using indendation as code blocks,
you can create a C::TinyCompiler package to enable that for you. If you want to use the fat
arrow C<< => >> to mean something special in your code, you can write a C::TinyCompiler
package to enable that for you. The sky is the limit.

=back

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests at the project's main github page:
L<http://github.com/run4flat/perl-TCC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::TinyCompiler::package


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

