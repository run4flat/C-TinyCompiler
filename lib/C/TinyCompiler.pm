package C::TinyCompiler;

use 5.010;
use strict;
use warnings;
use Carp;

use warnings::register;

=head1 NAME

C::TinyCompiler - Full C JIT compiling using the Tiny C Compiler

=head1 VERSION

Version 0.01

=cut

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'C::TinyCompiler', $VERSION;
}

=head1 SYNOPSIS

Compile C-code in memory at runtime.

 ## A really basic example ##
 
 use strict;
 use warnings;
 use C::TinyCompiler;
 
 # Build a compiler context
 my $context = C::TinyCompiler->new();
 
 # Add some code (but don't compile yet)
 $context->code('Body') = q{
     void say_hi() {
         printf("Hello from C::TinyCompiler!\n");
     }
 };
 
 # Compile our C code
 $context->compile;
 
 # Call our function
 $context->call_void_function('say_hi');
 
 
 ## Make a function that takes arguments ##
 
 # Use the C::TinyCompiler::Callable package/extension
 $context = C::TinyCompiler->new('C::TinyCompiler::Callable');
 
 # Add a function that does something mildly useful
 $context->code('Body') = q{
     C::TinyCompiler::Callable
     double positive_pow (double value, int exponent) {
         double to_return = 1;
         while (exponent --> 0) to_return *= value;
         return to_return;
     }
 };
 
 # Compile our C code
 $context->compile;
 
 # Retrieve a subref to our function
 my $pow_subref = $context->get_callable_subref('positive_pow');
 
 # Exercise the pow subref
 print "3.5 ** 4 is ", $pow_subref->(3.5, 4), "\n";
 
 
 ## Throw exceptions ##
 
 # Use the C::TinyCompiler::Callable and
 # C::TinyCompiler::Perl::Croak packages/extensions
 $context = C::TinyCompiler->new( qw< ::Callable ::Perl::Croak > );
 
 # Add a positive, integer pow() function
 $context->code('Body') = q{
     C::TinyCompiler::Callable
     double positive_pow (double value, int exponent) {
         if (exponent < 0) {
             croak("positive_pow only accepts non-negative exponents");
         }
         double to_return = 1;
         while (exponent --> 0) to_return *= value;
         return to_return;
     }
 };

=head1 DESCRIPTION

This module provides Perl bindings for the Tiny C Compiler, a small, ultra-fast
C compiler that can compile in-memory strings of C code, and produce machine
code in memory as well. In other words, it is a full C just-in-time compiler. It
works for x86 and ARM processors. The jit-compilation capabilities offered by
this module are known to work on Windows, Linux, and Mac OS X.

The goal for this family of modules is to not only provide a useful interface to
the compiler itself, but to also provide useful mechanisms for building
libraries that utilize this module framework. Eventually I would like to see a
large collection of pre-canned data structures and associated algorithms that
can be easily assembled together for fast custom C code. I would also like to
see C::TinyCompiler modules for interfacing with Perl-based C libraries such as
PDL, Prima, and Imager, or major Alien libraries such as SDL, OpenGL, or
WxWidgets. But this is only the early stages of development, and the key modules
that provide useful functionality are:

=over

=item L<C::TinyCompiler::Callable>

This module lets you write functions in C that can be invoked from Perl, much
like L<Inline::C>.

=item L<C::TinyCompiler::StretchyBuffer>

This module provides a data structure that handles I<exactly> like a C array but
has additional functionality to dynamically change the length, retrieve the
current length, and push and pop data at the end.

=item L<C::TinyCompiler::Perl::Croak>

This module provides an interface to Perl's C-level C<croak> and C<warn>
functions, as well as their v-prefixed variants. This way, you can safely throw
exceptions from your TinyCompiler-compiled C code.

=back

=head1 PRE-COMPILE METHODS

The compiler context has three main events that divide the usage into two
stages. Those events are creation, compilation, and destruction. Between
creation and compilation you can do many things to the compiler context to
prepare it for compilation, like adding library paths, setting and unsetting
C<#define>s, and adding code. After compilation, you can retrieve symbols (which
is how you get at the code or globals that you just compiled) and execute
compiled functons

=head2 new

Creates a new Tiny C Compiler context. All compiling and linking needs to be run
in a context, so before creating any new code, you'll need to create one of
these.

Arguments are simply the names of packages that you want applied to your
compiler context. For example,

 my $context = C::TinyCompiler->new('::Perl::SV');
 my $context = C::TinyCompiler->new('::Perl::SV', '::Perl::AV');

C::TinyCompiler packages are to C::TinyCompiler what modules are to Perl. They
add some sort of functionality to the compiler context, whether that's a set of
functions or some fancy source filtering. To learn more about adding packages to
your compiler context, see L</apply_packages>.

=cut

my %is_valid_location = map { $_ => '' } qw(Head Body Foot);

sub new {
	my $class = shift;
	
	# Create a new context object with the basics
	my $self = bless {
		has_compiled => 0,
		error_message => '',
		# Code locations
		%is_valid_location,
		# include paths
		include_paths => [],
		sysinclude_paths => [],
		# library stuff
		libraries => [],
		library_paths => [],
		# symbols (like function pointers)
		symbols => {},
		# Preprocessor definitions:
		pp_defs => {},
	};
	
	# Process any packages:
	$self->apply_packages(@_);
	
	# Return the prepared object:
	return $self;
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

=head2 add_include_paths, add_sysinclude_paths

Adds include paths or "system" include paths to the compiler context. For
example,

 $context->add_include_paths qw(C:\my\win32\headers /my/linux/headers);

Include paths are places to search when you say C<< #include <lib.h> >> or
C<$include "mylib.h"> in your C source. The only difference between a system
include path and a regular include path is that all regular include paths are
searched before any system include paths. Other important things to know include

=over

=item Quote-includes check '.' but angle-bracket includes do not

The only difference between saying C<#include "mylib.h"> and
C<< #include <mylib.h> >> is that the first one always looks for F<mylib.h>
in the current working directory before checking the include paths, whereas
the second one only checks the include paths. By I<current working directory>,
I mean the working directory when the L</compile> function is invoked.

=item Adding to the path is like using C<-I>

Adding include paths is similar to the C<-I> command line argument that
you get with most (all?) compilers.

=item First added = first checked

Suppose you have files F<foo/bar.h> and F<foo/baz/bar.h> and you add both C<foo>
and C<foo/baz> to your list of include paths. Which header will you get? The
compiler will search through the include paths starting with the first path
added. In other words, if your file layout looks like this:

 foo/
   bar.h
   baz/
     bar.h

then this series of commands will pull in F<foo/bar.h> rather than
F<foo/baz/bar.h>:

 use File::Spec;
 $context->add_include_paths('foo', File::Spec->catfile('foo', 'baz'));
 $context->code('Head') .= {
     #include "bar.h"
 };

=item The last include path is checked before the first sysinclude path

When your C code has C<#include "lib.h"> or C<< #include <lib.h> >>, the search
process starts off looking in all directories that are in the include path list,
followed by all the directories in the system include path list. This is
important if you are writing a C::TinyCompiler package. If you want your user to potentially
override a header file by adding an include path, you should specify any special
include paths with the sysinclude.

=item Backslashes and qw(), q()

As a notational convenience, notice that you do not need to escape the
backslashes for the Windows path when you use C<qw>. That makes Windows paths
easier to read, especially when compared to normal single and double quoted
strings.

=item Nonexistent paths are OK

Adding nonexistent paths will not trigger errors nor cause the compiler to
croak, so it's ok if you throw in system-dependent paths. It may lead to a minor
performance hit when the compiler searches for include files, but that's not
likely to be a real performance bottleneck.

=item Path-separators are OK, but not cross-platform

It is safe to submit two paths in one string by using the system's default path
separator. For example, this works on Linux:

 # Linux
 $context->add_include_paths('/home/me/include:/home/me/sources');
 # Windows
 $context->add_include_paths('C:\\me\\include;C:\\me\\sources');

However, the path separator is system-specific, i.e. not cross-platform. Use
sparingy if you want cross-platform code.

=item No known exceptions

There is a line of code in these bindings that check for bad return values, and
if triggered it will issue an error that reads thus:

 Unkown tcc error including path [%s]

However, as of the time of writing, C::TinyCompiler will never trigger that error, so I find
it highly unlikely that you will ever see it. If you do, these docs and the code
need to be updated to query the source of the error and be more descriptive.

=item Set paths before compiling

This should be obvious, but it's worth pointing out that you must set the
include paths before you L</compile>. If you try to set include paths after
compilation, you will not cause any change in the context's state; if you have
warnings enabled, you will get a message like:

 Adding include paths after the compilation phase has no effect.

or

 Adding sysinclude paths after the compilation phase has no effect.

=back

=cut

sub _add_paths {
	my ($self, $type) = (shift, shift);
	
	# Give a warning if the compiler has already run.
	if ($self->has_compiled) {
		warnings::warnif("Adding $type paths after the compilation phase has no effect.");
	}
	else {
		push @{$self->{"${type}_paths"}}, @_;
	}
}

sub add_include_paths {
	my $self = shift;
	$self->_add_paths('include', @_);
}

sub add_sysinclude_paths {
	my $self = shift;
	$self->_add_paths('sysinclude', @_);
}

=head2 add_library_paths

Adds library paths, similar to using C<-L> for most compilers. For example,

 $context->add_library_paths('C:\\mylibs', '/usr/home/david/libs');

would be equivalent to saying, on the command line:

 cc ... -LC:\\mylibs -L/usr/home/david/libs ...

Notice that the paths are not checked for existence before they are added. Also,
adding library paths after the compilation phase has no effect and, if you have
warnings enabled, will issue this statement:

 Adding library paths after the compilation phase has no effect.

=cut

sub add_library_paths {
	my $self = shift;
	$self->_add_paths('library', @_);
}

=head2 add_librarys

Adds the libraries, similar to using C<-l> for most compilers. For example,

 $context->add_librarys('gsl', 'cairo');

would be equivalent to saying, on the command line:

 cc ... -llibgsl -llibcairo ...

You must perform all additions before the compilation phase.

If the compiler cannot find one of the requested libraries, it will croak saying

 Unable to add library %s


=cut

sub add_librarys {
	my $self = shift;
	if ($self->has_compiled) {
		
	}
	push @{$self->{libraries}}, @_;
}


=head2 define

This defines a preprocessor symbol (not to be confused with L</add_symbols>,
which adds a symbol to the compiler lookup table). It takes the preprocessor
symbol name and an optional string to which it should be expanded. This
functions much like the C<-D> switch for most (all?) compilers. In this way,
having this in your Perl code 

 $context->define('DEBUG_PRINT_INT(val)'
     , 'printf("For " #val ", got %d\n", val)');

gives similar results as having this at the top of your C code:

 #define DEBUG_PRINT_INT(val) printf("For " #val ", got %d\n", val)

In fact, tcc (and thus C::TinyCompiler) even supports variadic macros, both
directly in C code and using this method.

=for details
The above statements are covered in the test suite, 112-compile-define.t

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
         , 'printf("For " #val ", got %d\n", val)');
 }
 else {
     $context->define('DEBUG_PRINT_INT(val)');
 }

Another nicety of Perl-side macros is that they can be defined as multi-line
more cleanly. For example, this C macro

 #define DEBUG_PRINT_INT(val) \
     do { \
         printf("For " #val ", got %d\n", val); \
     } while (0)

can be notated with a Perl-side define simply as

 $context->define ('DEBUG_PRINT_INT(val)' => q{
     do {
         printf("For " #val ", got %d\n", val);
     } while (0)
 });

There are differences between how Perl-side and C-side macro definitions
operate, but arguably the
most important is that the second form lets you query the definition from Perl.
The overhead involved for such queries likely makes C<#define> statements in
C code are marginally faster than Perl-side defines, but I have a hard time
believing that is a real bottleneck in your code. I suggest you optimize this
for developer time, not execution time.

If you do not provide a symbol, an empty string will be used instead. This
varies slightly form the C<libtcc> usage, in which case if you provide a null
pointer, the string "1" is used. Thus, if you want a value of "1", you will need
to explicitly do that.

If you attempt to modify a preprocessor symbol that has already been defined,
the behavior will depend on whether or not you have enabled C<C::TinyCompiler>
warnings. These warnings are enabled if you say C<use warnings> in your code, so
if you are like most people, these are probably on by default. If you want to
suppress redefinition warnings for a small chunk of code, you should say
something like this:

 ...
 {
     no warnings 'C::TinyCompiler';
     $context->define('symbol', 'new_value');
 }
 ...

Also, this function will croak if you attempt to modify a preprocessor symbol
after you have compiled your code, saying:

 Error defining [$symbol_name]:
   Cannot modify a preprocessor symbol
   after the compilation phase

If you want to check if the context has compiled, see L</has_compiled>.

=cut

sub define {
	my $self = shift;
	my $symbol_name = shift;
	my $set_as = shift || '';
	
	# Give a warning if the compiler has already run.
	if ($self->has_compiled) {
		warnings::warnif("Setting preprocessor definition for $symbol_name after the compilation phase has no effect");
	}
	else {
		# Set the value in the compiler state:
		warnings::warnif("Redefining $symbol_name")
			if exists $self->{pp_defs}->{$symbol_name};
		$self->{pp_defs}->{$symbol_name} = $set_as;
	}
}

=head2 is_defined

Returns a boolean value indicating whether or not the given preprocessor symbol
has been defined using the L</define> method. You can call this method both
before and after compiling your code, but this is not aware of any C<#define>
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

If you defined the given preprocessor macro using the L</define> method, this
returns the (unexpanded) preprocessor definition that you supplied. If the macro
was not defined using L</define> (or has subsequently been L</undefine>d), this
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
grumble if you C<use warnings>. Second, the values of 0 or the blank string
(blank strings are the default values if no value is supplied when you call
L</define>) are valid values even though these are false in boolean context.
Thus, if you simply want to know if a preprocessor symbol is defined, you should
use L</is_defined> instead. That is to say:

 # BAD UNLESS YOU REALLY MEAN IT
 if ($context->definition_for('DEBUGGING')) {
     # ...
 }
 
 # PROBABLY WHAT YOU MEANT TO SAY
 if ($context->is_defined('DEBUGGING')) {
     # ...
 }

=cut

sub definition_for {
	my ($self, $symbol_name) = @_;
	return $self->{pp_defs}->{$symbol_name};
}

=head2 undefine

Undefines the given preprocessor symbol name. Remember that this happens before
any of the code has been compiled; you cannot call this dynamically in the
middle of the compilation process.

This should not throw any errors. In particular, it should not gripe at you if
the symbol was not defined to begin with. However, it is still possible for
something deep inside tcc to throw an error, in which case you will get an
error message like this:

 Error undefining preprocessor symbol [%s]: %s

But I don't expect that to happen much.

=cut

sub undefine {
	my ($self, $symbol_name) = @_;
	
	# Give a warning if the compiler has already run.
	if ($self->has_compiled) {
		warnings::warnif("Removing preprocessor definition for $symbol_name after the compilation phase has no effect");
	}
	else {
		delete $self->{pp_defs}->{$symbol_name};
	}
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

working here - note that warnings are not issued for changing code values after
the compilation phase, but such changes can have no effect.

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
			unless exists $is_valid_location{$location};
	
	$self->{$location};
}

=head2 line_number

Build a line number directive for you. Use like so:

 $context->code('Body') .= C::TinyCompiler::line_number(__LINE__) . q{
     void test_func (void) {
         printf("Success!\n");
     }
 };

Suppose you have an error in your code and did not use this (or some other
means) for indicating your line numbers. The offending code could be

 $context->code('Body') .= q{
     void test_func (void {
         printf("Success!\n");
     }
 };

which, you will notice, forgets to close the parenthesis in the function
definition. This will raise an error that would look like this:

 Unable to compile at Body line 2: parameter declared as void

Although it tells you the section in which the error occurred, if you have a
complex script that adds code in many places, you may have no idea where to find
offending addition in your Perl code. Fortunately, C (and Perl) allows
you to give hints to the compiler using a C<#line> directive, which is made even
easier with this function. Without C<line_number>, you would say something like:

 $context->code('Body') .= "\n#line " . (__LINE__+1) . ' "' . __FILE__ . q{"
     ... code goes here ...
 };

and then your error reporting would say where the error occurred with respect to
the line in your script. That formula is long-winded and error prone, so you can
use this useful bit of shorthand instead:

 $context->code('Body') .= C::TinyCompiler::line_number(__LINE__) . q{
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
	return "\n#line $line \"$filename\"";
}

=head2 apply_packages

Adds the given packages to this compiler context. The names should be the name
of the Perl package that has the functions expected by the C::TinyCompiler
package mechanisms:

 $context->apply_packages qw(C::TinyCompiler::Perl::SV C::TinyCompiler::Perl::AV);

The C<C::TinyCompiler> is optional, so this is equivalent to:

 $context->apply_packages qw(::Perl::SV ::Perl::AV);

Options are package-specific strings and should be specified after the
package name and enclosed by parentheses:

 $context->apply_packages qw(::Perl::SV(most) ::Perl::AV(basic))

You can call this function multiple times with different package names. However,
a package will only be applied once, even if you specify different package
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

For more discussion on packages, see L</MANAGING PACKAGES>.

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
		# Add C::TinyCompiler if it starts with ::
		$package_spec = 'C::TinyCompiler' . $package_spec
			if index ($package_spec, ':') == 0;
		# Pull out the package options:
		my @options;
		if ($package_spec =~ s/\((.+)\)$//) {
			my $options = $1;
			@options = split /,/, $options;
		}
		
		# Skip if already applied
		next PACKAGE if $self->is_package_known($package_spec);
		
		# Pull in the package if it doesn't already exist:
		unless ($package_spec->can('apply')) {
			# All this mumbo jumbo is used to ensure that we get proper line
			# number reporting if the package cannot be use'd.
			eval '#line ' . (__LINE__-1) . ' "' . __FILE__ . "\"\nuse $package_spec";
			croak($@) if $@;
		}
		
		# Make sure we don't have any conflicting packages:
		if ($package_spec->conflicts_with($self, keys %{$self->{applied_package}})
			or grep {$_->conflicts_with($self, $package_spec)} keys %{$self->{applied_package}}
		) {
			# If there's a conflict, then mark the package as blocked
			$self->block_package($package_spec);
		}
		else {
			# Apply the package, storing the options (for use later under the
			# symbol application).
			$package_spec->apply($self, @options);
			$self->{applied_package}->{$package_spec} = [@options];
		}
	}
}

=head1 MANAGING PACKAGES

Certain packages require other packages, and some packages do not play nicely
together. The current package management system is not very sophisticated, but
it does provide a means for packages to indicate dependencies and conflicts with
others. In general, all of this should be handled by the packages and manual
intervention from a user should usually not be required.

As far as the compiler is concerned, a package can be in one of three
states: (1) applied, (2) blocked, or (3) unknown. An applied package is any
package that you have applied directly or which has been pulled in as a package
dependency (but which has not been blocked). A blocked package is one that
should should not be applied. An unknown package is one that simply has not
been applied or blocked.

As an illustration of this idea, consider the L<C::TinyCompiler::Perl> package and the
light-weight sub-packages like L<C::TinyCompiler::Perl::Croak>. The light-weight packages
provide a exact subset of L<C::TinyCompiler::Perl>, so if L<C::TinyCompiler::Perl> is loaded, the
sub-packages need to ensure that they do not apply themselves or, if they have
already been applied, that they remove themselves. This check and manipulation
occurs during the sub-packages' call to C<conflicts_with>

=head2 is_package_applied, is_package_blocked, is_package_known

Three simple methods to inquire about the status of a package. These return
boolean values indicating whether the package (1) is currently being applied, 
(2) is currently blocked, or (3) is either being applied or blocked.

=cut

sub is_package_applied {
	my ($self, $package) = @_;
	return exists $self->{applied_package}->{$package};
}

sub is_package_blocked {
	my ($self, $package) = @_;
	return exists $self->{blocked_package}->{$package};
}

sub is_package_known {
	my ($self, $package) = @_;
	return $self->is_package_applied($package)
		or $self->is_package_blocked($package);
}

=head2 block_package

Blocks the given package and removes its args from the applied package list if
it was previously applied.

=cut

sub block_package {
	my ($self, $package) = @_;
	delete $self->{applied_package}->{$package};
	$self->{blocked_package}->{$package} = 1;
}

=head2 get_package_args

Returns the array ref containing the package arguments that were supplied when
the package was applied (or an empty array ref if the package was never applied
or has subsequently been blocked). This is the actual array reference, so any
manipulations to this array reference will effect the reference returned in
future calls to C<get_package_args>.

=cut

sub get_package_args {
	my ($self, $package) = shift;
	return $self->{applied_package}->{$package} || [];
}

=head1 COMPILE METHODS

These are methods related to compiling your source code. Apart from C<compile>,
you need not worry about these methods unless you are trying to create a C::TinyCompiler
package.

=head2 compile

Concatenates the text of the three code sections, jit-compiles them, applies all
symbols from the included packages, and relocates the code so that symbols can
be retrieved. In short, this is the transformative step that converts your code
from ascii into machine.

This step does far more than simply invoke libtcc's compile function. At the
time of writing, tcc only supports a single uncompiled compiler state at a time.
To properly handle this, C::TinyCompiler defers creating the actuall TCCState
object as long as possible. Calling the C<compile> method on your compiler
context actually performs these steps:

=over

=item 1. Create TCCState

An actual TCCState struct is created, to which the following operations are
applied.

=item 2. Apply preprocessor definitions, paths, libraries

All preprocessor defintions, include paths, library paths, and libraries are
added to the compiler state.

=item 3. Invoke preprocessing methods of all C::TinyCompiler packages

Packages can perform preprocessing on the compiler context (and in particular,
the code strings) just before the actual compilation step. This allows them to
dynmically add or remove elements to your code, like source-filters. Or they
could hold off to perform other changes to the compiler context until just
before the compilation step, although this is generally not needed.

=item 4. Code assembly and compilation

The code is assembled and compiled.

=item 5. Apply symbols and relocate the machine code

Symbols (such as dynamically loaded functions) are applied, the final machine
code is relocated, and the memory pages holding that code are marked as
executable.

=back

This means that nearly all of the interaction with libtcc itself is deferred
until you call this function. As each of those interactions could encounter
trouble, this function may croak for many reasons.

=over

=item This context has already been compiled

You are only allowed to compile a context once.

=item Error defining processor symbol <name>: <message>

tcc encountered trouble while trying to define the given preprocessor symbol.
Duplicate preprocessor symbols should not occurr at this stage, so this error
likely means that your definition is malformed.

=item Error adding include path(s): <message>
=item Error adding library path(s): <message>

An include path, sysinclude path, or library path gave trouble. The tcc source
code has no code path that should issue this error, so this should never happen.
If it does, either you really messed something up, or there's a bug in this
module. :-)

=item Error adding library(s): <message>

tcc encountered trouble adding one or more of your specified libraries. Hopefully
the message explains the trouble well enough.

=item Unable to compile ...

If your code has a syntax error or some other issue, you will get this message.
If the reported line numbers do not help, consider using L</line_numbers> to
improve line number reporting.

=item Error adding symbol(s): <message>

If you specify symbols that have already been defined elsewhere, the compiler
will thwart your attempts with this message. Make sure that you have not defined
a like-named symbol already. In particular, be sure not to define a symbol that
was defined already by one of your packages.

=item Unable to relocate: <message>

The last step in converting your C code to machine-executable code is relocating
the bytecode. This could fail, though I do not understand compilers well enough
to explain why. If I had to guess, I would say you probably ran out of memory.
(Sorry I cannot provide more insight into how to fix this sort of problem.
Feedback for a better explanation would be much appreciated. :-)

=back

=cut

sub compile {
	my $self = shift;
	
	# Make sure we haven't already compiled with this context:
	croak('This context has already been compiled') if $self->has_compiled;
	
	# Create the actual TCCState object:
	$self->_create_state;
	
	# Apply the #defines and add the #include paths
	my %defs = %{$self->{pp_defs}};
	while (my ($name, $value) = each %defs) {
		$self->_define($name, $value);
		$self->report_if_error("Error defining preprocessor symbol [$name]: MESSAGE");
	}
	$self->_add_include_paths(@{$self->{include_paths}});
	$self->_add_sysinclude_paths(@{$self->{sysinclude_paths}});
	$self->report_if_error("Error adding include path(s): MESSAGE");
	
	# Add the library stuff:
	$self->_add_library_paths(@{$self->{library_paths}});
	$self->report_if_error("Error adding library path(s): MESSAGE");
	$self->_add_libraries(@{$self->{libraries}});
	$self->report_if_error("Error adding library(s): MESSAGE");
	
	# Allow packages to perform any preprocessing they may want:
	while (my ($package, $options) = each %{$self->{applied_package}}) {
		$package->preprocess($self, @$options);
	}
	
	# Assemble the code (with primitive section indicators) and compile!
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
	
	# Apply the pre-compiled symbols (function pointers, etc):
	while (my ($package, $options) = each %{$self->{applied_package}}) {
		$package->apply_symbols($self, @$options);
	}
	# Apply any other symbols that were added:
	$self->_add_symbols(%{$self->{symbols}});
	$self->report_if_error("Error adding symbol(s): MESSAGE");

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
	
	# Mark the compiler as post-compile
	$self->{has_compiled} = 1;
}

=head2 add_symbols

Adds symbols to a compiler context. This function expects the symbols as

 symbol_name => pointer

pairs. By I<symbol>, I mean any C thing that you want to give a name in your
compiler context. That is, you can add a function to your compiler context that
was compiled elsewhere, or tell the compiler context the location of some
variable that you wish it to access as a global variable.

This function requires that you send a true C pointer that points to your
symbol. This only makes sense if you have a way to get C pointers to your
symbols. This would be the case if you have compiled code with a separate C::TinyCompiler
context (in which case you would use L</get_symbols> to retrieve that pointer),
or if you have XS code that can retrieve a pointer to a function or global
variable for you.

working here - add examples, and make sure we can have two compiler contexts at
the same time.

For example, the input should look like this:

 $context->add_symbols( func1 => $f_pointer, max_N => $N_pointer);

If you fail to provide key/value pairs, this function will croak saying

 You must supply key => value pairs to add_symbols

=cut

sub add_symbols {
	my $self = shift;
	
	# working here - not sure if it's safe to add symbols after relocation.
	
	croak('You must supply key => value pairs to add_symbols')
		unless @_ % 2 == 0;
	
	my %symbols = @_;
	while (my ($symbol, $pointer) = each %symbols) {
		# Track the symbols, warning on redefinitions
		warnings::warnif("Redefining $symbol")
			if exists $self->{symbols}->{$symbol};
		$self->{symbols}->{$symbol} = $pointer;
	}
}

=head1 POST-COMPILE METHODS

These are methods you can call on your context after you have compiled the
associated code.

=head2 get_symbols

Retrieves the pointers to a given list of symbols and returns a key/value list
of pairs as

 symbol_name => pointer

=cut

sub get_symbols {
	croak('Cannot retrieve symbols before compiling') unless $_[0]->has_compiled;
	goto &_get_symbols;
}

=head2 get_symbol

Like L</get_symbols>, but only expects a single symbol name and only returns the
pointer (rather than the symbol name/pointer pair). For example,

 $context->code('Body') .= q{
     void my_func() {
         printf("Hello!\n");
     }
 };
 $context->compile;
 my $func_pointer = $context->get_symbol('my_func');

=cut

sub get_symbol {
	my ($self, $symbol_name) = @_;
	croak("Cannot retrieve symbol $symbol_name before compiling")
		unless $self->has_compiled;
	my (undef, $to_return) = $self->get_symbols($symbol_name);
	return $to_return;
}

=head2 call_void_function

Takes the name of a compiled function and calls it without passing any
arguments. In other words, this assumes that your function has the following
definition:

 void my_func (void) {
     ...
 }

This is pretty dumb because it is nearly impossible to pass parameters into the
function, but is useful for testing purposes. Note that if you try to call it
before you have compiled, you will get this message:

 Cannot call a function before the context has compiled.

=cut

sub call_void_function {
	my ($self, $function) = @_;
	
	# Make sure we've compiled
	croak('Cannot call a function before the context has compiled.')
		unless $self->has_compiled;
	
	# Call the XS function:
	$self->_call_void_function($function);
}

=head2 is_compiling

An introspection method to check if the context is currently in the compile
phase. This is particularly useful for packages whose behavior may depend on
whether they are operating pre-compile, post-compile, or during compile.

=cut

sub is_compiling {
	my $self = shift;
	return exists $self->{_state} and not $self->{has_compiled};
}

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

=head1 TODO

Add docs for report_if_error and get_error_message

Research and add C<set_linker> if it seems appropriate.

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests at the project's main github page:
L<http://github.com/run4flat/perl-TCC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::TinyCompiler


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

=head1 ACKNOWLEDGEMENTS

The tcc developers who have continued refining and improving the wonderlul
little compiler that serves as the basis for this project!

=head1 LICENSE AND COPYRIGHT

Code copyright 2011-2012 Northwestern University. Documentation copyright
2011-2013 David Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of TCC
