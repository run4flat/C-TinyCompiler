package TCC;

use 5.006;
use strict;
use warnings;
use Carp;

=head1 NAME

TCC - Full C JIT compiling using the Tiny C Compiler

=head1 VERSION

Version 0.01

=cut

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'TCC', $VERSION;
}

use constant CROAK  => 1;
use constant WARN   => 2;
use constant IGNORE => 3;
our $REDEFINE = WARN;

=head1 SYNOPSIS

Compile C-code in memory at runtime.

 use TCC;
 
 my $context = TCC->new();
 # working here
 
 my $func_ref = $state->

=head1 METHODS

The compiler context has three main events that divide the usage into two
stages. Those events are creation, compilation, and destruction. Between
creation and compilation you can do many things to the compiler context to
prepare it for compilation, like adding library paths, setting and unsetting
C<#define>s, and adding symbols. After compilation (and relocation), you can
retrieve symbols, which is how you get at the code that you just compiled.

=head2 new

Creates a new Tiny C Compiler context. All compile behavior needs to be run in
a context, so before creating any new code, you'll need to create a context.

There are certain things that you probably didn't mean to do. For these, you can
have the compiler croak, spit out a warning, or simply ignore and handle
silently. These include:

working here - this needs to be clarified

=over

=item redefine

when you try to redefine a preprocessor symbol that already exists; default
value is CROAK

=back

=cut

sub new {
	my $class = shift;
	croak("Error creating new TCC context: options must be key/value pairs")
		unless @_ % 2 == 0;
	
	# Handle the arguments.
	my %args = @_;
	
	# Create a new context:
	my $self = _new;
	
	# Add some additional stuff to the context:
	$self->{prepend} = '';
	$self->{error_message} = '';
	$self->{has_compiled} = 0;
	$self->{has_relocated} = 0;
	
	# Return this constructed hash
	return bless $self;
}

=head2 add_include_path, add_sysinclude_path

Adds an include path or system include path to the compiler context. The first
is similar to the -I command line argument that you get with most (all?)
compilers. (I'm not sure how to set the sytem include paths with gcc or any
other compiler.) By specifying an include path, you can use statements like

 #include "my_header.h"

and the compiler will look for C<my_header.h> in the various include paths. The
sysinclude path lets you use angle brackets in a similar way, like so:

 #include <my_header.h>

Frankly, I'm not sure how often you'll want to fiddle with the sysinclude paths.
In general, you should probably stick with just adding to the normal include
path.

All include paths must be set before calling C<compile_string>.

=cut

sub add_include_path {
	my ($self, $path) = @_;
	# Make sure the path makes sense:
	croak("Error including path [$path]: path does not appear to exist")
		unless -d $path;
	_add_include_path($self->{_state}, $path);
	
	# Croak if anything happened:
	$self->report_if_error("Error including path [$path]: MESSAGE");
}

# Report errors if they crop-up:
sub report_if_error {
	my ($self, $to_say) = @_;
	if (my $msg = $self->get_error_message) {
		$to_say =~ s/MESSAGE/$msg/;
		croak($to_say);
	}
}

sub get_error_message {
	my $self = shift;
	my $msg = $self->{error_message};
	$self->{error_message} = '';
	return $msg;
}

sub add_sysinclude_path {
	my ($self, $path) = @_;
	# Make sure the path makes sense:
	croak("Error including syspath [$path]: path does not appear to exist")
		unless -d $path;
	_add_sysinclude_path($self->{_state}, $path);
	
	# Croak if anything happened:
	$self->report_if_error("Error including syspath [$path]: MESSAGE");
}

=head2 define

This defines a preprocessor symbol (not to be confused with L<add_symbol>, which
adds a symbol to the compiler lookup table). It takes the preprocessor symbol
name and an optional string to which it should be expanded. This functions much
like the C<-D> switch for the GNU C Compiler (and possibly others). In this way,
having this in your Perl code

 $context->define('DEBUG_PRINT_INT(val)'
     , 'printf("For " #val ", got %d\n", val));

gives similar results as having this at the top of your C code:

 #define DEBUG_PRINT_INT(val) printf("For " #val ", got %d\n", val)

Normally in C code, you might has such a definition within a C<#ifdef> block
like this:

 #ifdef DEBUG
 #    define DEBUG_PRINT_INT(val) printf("For " #val ", got %d\n", val)
 #
 #else
 #    define DEBUG_PRINT_INT(val)
 #endif

Since you control what gets defined with your Perl code, this can be changed to
something like this:

 if ($context->{is_debuggin}) {
     $context->define('DEBUG_PRINT_INT(val)'
         , 'printf("For " #val ", got %d\n", val));
 }
 else {
     $context->define('DEBUG_PRINT_INT(val)');
 }

The difference between these two is that in the former all the macro
definitions are parsed by libtcc, whereas in the latter all the Perl code is
parsed by the Perl parser and libtcc only deals with definitions when the
C<define> function gets called. It's probably marginally faster to simply
include C<#ifdef> and C<#define> in your C code, but you can on retrieve the
preset value of a preprocessor symbol in your Perl code if you use the C<define>
method. It's a tradeoff between flexibility and speed.

If you do not provide a symbol, an empty string will be used instead. This
varies slightly form the libtcc usage, in which case if you provide a null
pointer, the string "1" is used. Thus, if you want a value of "1", you will need
to explicitly do that.

If you attempt to modify a preprocessor symbol that has already been defined,
the behavior will depend on the current (and potentially localized) value of
C<$TCC::REDEFINE>, which can be any of the three values C<TCC::CROAK>,
C<TCC::WARN>, or C<TCC::IGNORE>. The default behavior is to C<TCC::WARN> when
you are about to redefine a preprocessor symbol.

You can set a localized value of C<$TCC::REDEFINE> like so:

 $context->define('SYMBOL21', 5);
 
 # This will warn (by default):
 $context->define('SYMBOL21', 3);
 
 # Create a lexical scope for the localization:
 {
     local $TCC::REDEFINE = TCC::IGNORE;
     # This will be silent:
     $context->define('SYMBOL21');
 }
 
 # This will warn again:
 $context->define('SYMBOL21', 3);
 
Also, this function will croak if you attempt to modify a preprocessor symbol
after you have compiled your code. If you want to check if the context has
compiled, see L<has_compiled>.

=cut

sub define {
	my $self = shift;
	my $symbol_name = shift;
	my $set_as = shift || '';
	
	# working here - is this already handled by the tcc checking and error
	# handling?
	croak("Error defining [$symbol_name]: Cannot modify a preprocessor symbol after the compilation phase")
		if $self->{has_compiled};
	
	# Set the value in the compiler state:
	_define($self->{_state}, $symbol_name, $set_as);
	$self->{pp_defs}->{$symbol_name} = $set_as;
	
	# XXX working here - consider using warnings::register
	
	# Report errors as requested:
	if (my $message = $self->get_error_message) {
		# Clean the message:
		$message =~ s/<define>.*?$symbol_name //;
		if ($TCC::REDEFINE eq CROAK) {
			croak("Error defining [$symbol_name]: $message");
		}
		elsif($TCC::REDEFINE eq WARN) {
			carp("Warning defining [$symbol_name]: $message");
		}
	}
}

=head2 is_defined

Returns a boolean value indicating whether or not the given preprocessor symbol
has been defined using the L<define> method. This is not aware of any C<#define>
statements in your C code.

For example:

 $context->define('DEBUGGING', 2);
 
 # ...
 
 if ($context->is_defined('DEBUGGING')) {
     # More debugging code here.
 }

=cut

sub is_defined {
	my ($self, $symbol_name) = @_;
	return exists $self->{pp_defs}->{$symbol_name};
}

=head2 definition_for

If you defined the given preprocessor macro using the L<define> method, this
returns the (unexpanded) preprocessor definition that you supplied. If the
was not defined using L<define> (or has subsequently been L<undefine>d), this
function will return Perl's C<undef>.

For example:

 $context->define('DEBUGGING', 2);
 
 # ...
 
 if ($context->definition_for('DEBUGGING') > 2) {
     # Debugging code for highly debuggish setting
 }

Bear in mind a number of important aspects of how this works. First, if the
value is not defined, you will get an undefined value back; using this in a
mathematical expression or trying to convert it to a string will make Perl 
grumble if you C<use warnings>. Second, the values of 0 or the blank string are
valid values even though these are false in boolean context. Thus, if you
simply want to know if a preprocessor symbol is defined, you should use
L<is_defined> instead. That is to say:

 # BAD UNLESS YOU REALLY MEAN IT
 if ($context->definition_for('DEBUGGING')) {
     # ...
 }
 
 # PROBABLY WHAT YOU MEANT TO SAY
 if ($context->is_defined('DEBUGGIN')) {
     # ...
 }

=cut

sub definition_for {
	my ($self, $symbol_name) = @_;
	return $self->{pp_defs}->{$symbol_name};
}

=head2 undefine

Undefines the given preprocessor symbol name. Remember that this happens before
any of the code has been compiled; you cannot apply this dynamically in the
middle of the compilation process.

This should not throw any errors. In particular, it should not gripe at you if
the symbol was not defined to begin with.

=cut

sub undefine {
	my ($self, $symbol_name) = @_;
	# Remove the value in the compiler state and in the local cache:
	_undefine($self->{_state}, $symbol_name);
	delete $self->{pp_defs}->{$symbol_name};
	
	# Croak if anything happened:
	$self->report_if_error("Error undefining preprocessor symbol [$symbol_name]: MESSAGE");
}

=head2 todo

These are the functions I would like to create:

sub append_to_compile
sub get_text_to_compile
sub compile

=cut

sub has_compiled {
	die "not yet implemented";
}

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tcc at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TCC>.  I
will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TCC


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

Copyright 2011 David Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of TCC
