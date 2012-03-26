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
retrieve symbols, which is how you get at the code or globals that you just
compiled.

=head2 new

Creates a new Tiny C Compiler context. All compile behavior needs to be run in
a context, so before creating any new code, you'll need to create a context.

Arguments are specified as key => value pairs. At the moment, the only key is
the C<packages> key, which lets you specify a list of packages to apply to the
compiler context. The value associated with that key should be an anonymous
array (or just a string if you have only one package to include). For example,

 my $context = TCC->new(packages => '::Perl::SV');
 my $context = TCC->new(packages => ['::Perl::SV', ::Perl::AV']);

=cut

my %is_valid_location = map { $_ => 1 } qw(Head Body Foot);

sub new {
	my $class = shift;
	croak("Error creating new TCC context: options must be key/value pairs")
		unless @_ % 2 == 0;
	# Unpack the arguments.
	my %args = @_;
	
	# Create a new context object:
	my $self = bless _new;
	
	# Add some additional stuff to the context:
	$self->{$_} = '' foreach keys %is_valid_location;
	$self->{error_message} = '';
	$self->{has_compiled} = 0;
	
	# Process the packages key:
	if (my $packages = $args{packages}) {
		$packages = [$packages] unless ref($packages);
		$self->apply_packages(@$packages);
	}
	
	# Return the prepared object:
	return $self;
}

=head2 add_include_path, add_sysinclude_path

Adds an include path or system include path to the compiler context. The first
is similar to the -I command line argument that you get with most (all?)
compilers. (I'm not sure how to set the system include paths with gcc or any
other compiler.) By specifying an include path, you can use statements like

 #include "my_header.h"

and the compiler will look for C<my_header.h> in the various include paths. The
sysinclude path lets you use angle brackets in a similar way, like so:

 #include <my_header.h>

Frankly, I'm not sure how often you'll want to fiddle with the sysinclude paths.
In general, you should probably stick with just adding to the normal include
path.

All include paths must be set before calling L</compile>.

=cut

sub add_include_path {
	my ($self, $path) = @_;
	# Make sure the path makes sense:
	croak("Error including path [$path]: path does not appear to exist")
		unless -d $path;
	$self->_add_include_path($path);
	
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
	$self->_add_sysinclude_path($path);
	
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

Normally in C code, you might have such a definition within a C<#ifdef> block
like this:

 #ifdef DEBUG
 #    define DEBUG_PRINT_INT(val) printf("For " #val ", got %d\n", val)
 #else
 #    define DEBUG_PRINT_INT(val)
 #endif

Since you control what gets defined with your Perl code, this can be changed to
something like this:

 if ($context->{is_debugging}) {
     $context->define('DEBUG_PRINT_INT(val)'
         , 'printf("For " #val ", got %d\n", val));
 }
 else {
     $context->define('DEBUG_PRINT_INT(val)');
 }

The difference between these two is that in the former all the macro
definitions are parsed by C<libtcc>, whereas in the latter all the Perl code is
parsed by the Perl parser and C<libtcc> only deals with definitions when the
C<define> function gets called. It's probably marginally faster to simply
include C<#ifdef> and C<#define> in your C code, but you can retrieve the
preset value of a preprocessor symbol in your Perl code if you use the C<define>
method. It's a fairly minor tradeoff between flexibility and speed.

If you do not provide a symbol, an empty string will be used instead. This
varies slightly form the C<libtcc> usage, in which case if you provide a null
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
	$self->_define($symbol_name, $set_as);
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
	$self->_undefine($symbol_name);
	delete $self->{pp_defs}->{$symbol_name};
	
	# Croak if anything happened:
	$self->report_if_error("Error undefining preprocessor symbol [$symbol_name]: MESSAGE");
}

=head2 code

This lvalue sub lets you get, set, append to, and otherwise modify the contents
of the code in each of three regions. Any value is allowed so long as the
compile-phase can retrieve a useful string. This means that you can even set
the different code sections to be objects.

The location is the first argument and is a string, so the convention might look
something like this:

 $context->code('Head') = q{
     double my_dsum(double, double);
 };

though I generally recommend that you append to each section rather than
overwriting. To append to the Body section, for example, you would say:

 $context->code('Body') .= q{
     double my_dsum(double a, double b) {
         return a+b;
     }
 };

You can even hammer on these sections with a regular expression:

 $context->code('Head') =~ s/foo/bar/g;

Valid locations include:

=over

=item Head

Should come before any function definitions. Appropriate for function and global
variable declarations.

=item Body

Should contain function definitions.

=item Foot

Should come after function definitions. I'm not actually sure what should go
here, but I thought it might come in handy. :-)

=back

You can use whichever form of capitalization you like for the sections, so
C<head>, C<Head>, and C<HEAD> are all valid.

If you have a compiler error, line numbers will be meaningless if you do not
tell the compiler the line on which the code is run. To do this properly, use
L</line_number>, discussed below.

=cut

# Valid locations are defined in %is_valid_location, created near the
# constructor.

sub code :lvalue {
	my ($self, $location) = @_;
	# Canonicalize the location:
	$location = ucfirst lc $location;
	
	# Make sure they supplied a meaningful location:
	croak("Unknown location $location; must be one of "
		. join(', ', keys %is_valid_location))
			unless $is_valid_location{$location};
	
	$self->{$location};
}

=head2 line_number

Build a line number directive for you. Use like so:

 $context->code('Body') .= TCC::line_number(__LINE__) . q{
     ... code goes here ...
 };

If you run into a compiler issue with your code, you will get an error that
looks like this:

 Unable to compile at Body line 13: error: ',' expected (got "{")

Although it tells you the section in which the error occurred, you have no idea
where to find your Perl code that created this. Fortunately, C (and Perl) allow
you to give hints to the compiler using a C<#line> directive. Without this handy
function, you would say something like:

 $context->code('Body') .= '#line ' . (__LINE__+1) . ' "' . __FILE__ . q{"
     ... code goes here ...
 };

and then your error reporting would say where the error occurred with respect to
the line in your script. That formula is long-winded, so you can use this useful
bit of shorthand instead:

 $context->code('Body') .= TCC::line_number(__LINE__) . q{
     ... code goes here ...
 };

Still not awesome, but at least a little better.

=cut

sub line_number {
	my ($line) = @_;
	# The line needs to be incremented by one for the bookkeeping to work
	$line++;
	# Get the source filename using caller()
	my (undef, $filename) = caller;
	# Escape backslashes:
	$filename =~ s/\\/\\\\/g;
	return "#line $line \"$filename\"";
}

=head2 compile

Concatenates the text of the three code sections, jit-compiles them, appies all
symbols from the included packages, and relocates the code so that symbols can
be retrieved. In short, this is the transformative step that converts your code
from ascii into machine.

working here - document error messages

=cut

sub compile {
	my $self = shift;
	
	# Make sure we haven't already compiled with this context:
	croak('This context has already been compiled') if $self->has_compiled;
	
	# Assemble the code (with primitive section indicators):
	eval {
		my $code = '';
		for my $section (qw(Head Body Foot)) {
			$code .= "#line 1 \"$section\"\n" . $self->{$section};
		}
		$self->_compile($code);
		1;
	} or do {
		# We ran into a problem! Report the compiler issue (as reported from
		# the compiled line) if known:
		my $message = $self->get_error_message;
		if ($message) {
			# Fix the rather terse line number notation:
			$message =~ s/:(\d+:)/ line $1/g;
			# Change "In file included..." to "in file included..."
			$message =~ s/^I/i/;
			# Remove "error" in "... 13: error: ..."
			$message =~ s/: error:/:/;
			# Finally, die:
			die "Unable to compile $message\n";
		}
		
		# Otherwise report an unknown compiler issue, indicating the line in the
		# Perl script that called for the compile action:
		croak("Unable to compile for unknown reasons");
	};
	
	# Apply the pre-compiled symbols:
	while (my ($package, $options) = each %{$self->{applied_package}}) {
		$package->apply_symbols($self, @$options);
	}

	# Relocate
	eval {
		$self->_relocate;
		1;
	} or do {
		# We ran into a problem! Report the relocation issue, if known:
		$self->report_if_error("Unable to relocate: MESSAGE");
		# Report an unknown relocation issue if not known:
		croak("Unable to relocate for unknown reasons");
	};
	
	# Finish by setting the "compiled" flag:
	$self->{has_compiled} = 1;
}

=head2 apply_packages

Adds the given packages to this compiler context. The names should be the
package names.

 $context->apply_packages qw(TCC::Perl::SV TCC::Perl::AV);

The C<TCC> is optional, so this is equivalent to:

 $context->apply_packages qw(::Perl::SV ::Perl::AV);

Options are package-specific strings and should be specified after the
package name and enclosed by parentheses:

 $context->apply_packages qw(::Perl::SV(most) ::Perl::AV(basic))

You can call this function multiple times with different package names. However,
a package can only be applied once, even if you specify different package
options. Thus, the following will not work:

 $context->apply_packages '::Perl::SV(basic)';
 $context->apply_packages '::Perl::SV(refs)';

Instead, you should combine these options like so:

 $context->apply_packages '::Perl::SV(basic, refs)';

B<Note> that you can put spaces between the package name, the parentheses, and
the comma-delimited options, but C<qw()> will not do what you mean in that case.
In other words, this could trip you up:

 $context->apply_packages qw( ::Perl::SV(basic, refs) );

and it will issue a warning resembling this:

 Error: right parenthesis expected in package specification '::Perl::SV(basic,'

Again, these are OK:

 $context->apply_packages qw( ::Perl::SV(basic) );
 $context->apply_packages '::Perl::SV (basic)';

but this is an error:

 $context->apply_packages qw( ::Perl::SV (basic) );

and will complain saying:

 Error: package specification cannot start with parenthesis: '(basic)'
     Is this supposed to be an option for the previous package?

=cut

sub apply_packages {
	my ($self, @packages) = @_;
	
	# Run through all the packages and apply them:
	PACKAGE: for my $package_spec (@packages) {
		# Check for errors:
		croak("Error: right parenthesis expected in package specification '$package_spec'")
			if ($package_spec =~ /\(/ and $package_spec !~ /\)/);
		croak("Error: package specification cannot start with parenthesis: '$package_spec'\n"
			. "\tIs this supposed to be an option for the previous package?")
			if ($package_spec =~ /^\s*\(/);
		
		# strip spaces
		$package_spec =~ s/\s//g;
		# Add TCC if it starts with ::
		$package_spec = 'TCC' . $package_spec
			if index ($package_spec, ':') == 0;
		# Pull out the package options:
		my @options;
		if ($package_spec =~ s/\((.+)\)$//) {
			my $options = $1;
			@options = split /,/, $options;
		}
		
		# Skip if already applied
		next PACKAGE if $self->{applied_package}->{$package_spec};
		
		# Apply the package, storing the options (for use later under the
		# symbol application). All this mumbo jumbo is used to ensure that
		# we get proper line number reporting if the package cannot be use'd.
		eval '#line ' . (__LINE__-1) . ' "' . __FILE__ . "\"\nuse $package_spec";
		croak($@) if $@;
		$package_spec->apply($self, @options);
		$self->{applied_package}->{$package_spec} = [@options];
	}
}


=head2 call_function

This takes the name of the compiled function and a list of arguments and calls
the function. The function should be of the following form:

 void my_func (AV * input, AV * output);

The input array contains a direct reference to the values passed to the function
(which allows you to modify those variables in-place). The output array is
initially empty, but anything that you put into it will be returned.

For more details, see the section L</Writing Functions> below.

=cut

sub call_function {
	my $self = shift;
	my $func_name = shift;
	my @to_return;
	eval {
		$self->_call_function($func_name, \@_, \@to_return);
		1;
	} or do {
		my $message = $@;
		$message =~ s/ at .*\n//;
		croak($message);
	};
	return @to_return;
}

=head2 todo

These are the functions I would like to create:

=cut

=head2 has_compiled

An introspection method to check if the context has compiled it code or not. You
are still allowed to modify the content of your code sections after compilation,
but you will not be able to recompile it.

=cut

sub has_compiled {
	my $self = shift;
	return $self->{has_compiled};
}

# working here - consider using namespace::clean?

=head1 Writing Functions

Working here. Sorry. :-)

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
