package C::TinyCompiler::Callable;
use strict;
use warnings;
use parent 'C::TinyCompiler::package';
use Carp;

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'C::TinyCompiler::Callable', $VERSION;
}


sub apply {
	my (undef, $state, $callable_package) = @_;
	$callable_package = __PACKAGE__ unless defined $callable_package;
	# Make sure the package is a valid package name
	$callable_package =~ /^[_A-Za-z]\w*(?:::\w+)*$/
		or croak("Bad callable package $callable_package; must be a valid Perl package name");
}

##############################################
# regexes for extracting function signatures #
##############################################
# I believe these force me to require 5.10? When do named captures arrive?

our (@matched_names, @matched_types);

my $function_sig_re = qr{
	### main pattern ###
	(?&clear_trackers)	# Clear the lexical variables holding our
						#   matched names
	\G(?&ws)+			# start where we left off (just before callable_symbol)
	(?&type)(?&ws)+		# function return type
	(?&name)			# function name (always exists if we reach this point
						#   due to look-ahead in type() )
	(*COMMIT)			# No going back after this
	(?&ws)* \(
		(?&ws)*(?:			# start of the alternation group
			(?=\))	|			# either explicitly empty
			void(?&ws)*(?=\)) |	# ... or explicitly void ...
								# ... or an argument list:
			(?&type)(?&ws)+		# first argument type
			(?&name)			# first argument name
			(?:					# optional additional arguments
				(?&ws)*,(?&ws)*	# separated from previous arg
				(?&type)(?&ws)+	# additional argument type
				(?&name)		# additional argument name
			)*					# zero or more additional arguments
			(?&ws)*				# with optional trailing spaces
			(?&comma_check)		# helper check for trailing commas
		)					# end of the alternation group
		(*COMMIT)						
	\)					# close argument list
	
	
	### named subpattern definitions ###
	(?(DEFINE)
		# An identifier is a single C-valid identifier
		(?<identifier> (?>[_A-Za-z]\w*)\b )
		
		# General-purpose C whitespace:
		(?<ws> \s+ | /[*] .*? [*]/ )
		
		# A type is an identifier followed by more space-separated identifiers
		# (i.e. "unsigned int") then a pointer and/or spaces, with the knowledge
		# that an identifier follows
		(?<_type>
			(?&identifier) (?:(?&ws)+(?&identifier))*
			(?:(?&ws)*[*]+)*
			(?=(?&ws)*(?&identifier))
			(*COMMIT)
		)
		# A type captures a _type and stores the result on a stack
		(?<type>
			# Match a type
			((?&_type))
			# Save the match
			(?{push @C::TinyCompiler::Callable::matched_types, $+})
		)
		
		# A name captures an identifier and stores the results on a stack
		(?<name>
			# Match an identifier
			((?&identifier))
			# Save the match
			(?{push @C::TinyCompiler::Callable::matched_names, $+})
			# Commit; no going back after this
			(*COMMIT)
		)
		
		# A check for trailing commas
		(?<comma_check>
			# Croak when we see a comma
			,
			(?{
				die("Found a trailing comma in argument list\n")
			})
			|
			# Or supply an always-matching condition
			(?=[^,])
		)
		
		# Clear the lexical varibales holding our match results
		(?<clear_trackers>
			(?{
				@C::TinyCompiler::Callable::matched_types = ();
				@C::TinyCompiler::Callable::matched_names = ();
			})
		)
	)
}xms;

###################################################
# pack, unpack, and return handling lookup tables #
###################################################

# These are the known basic C types
my @basic_types = (qw(float double), 'long double');
push @basic_types, map { $_, "unsigned $_" } (qw(char short int long), 'long long');

# These are C code snippets used to handle return values. The code in
# return_lvals are placed on the left side of the function call, and should
# therefore include the equals sign if they are to capture the return value.
# Void functions do not captue anything and are therefore an empty string.
my %return_lvals = map {
	$_ => "$_ tmp =";
} @basic_types;
$return_lvals{void} = '';
# The code in return_packs are executed immediately after the function call
# and are supposed to pack the return results onto the return buffer. A
# semicolon is appended to the end, and is therefore not needed in these
# strings.
my %return_packs = map {
	$_ => "*(($_ *)returnlist) = tmp"
} @basic_types;
$return_packs{void} = '';

# Perl-side pack strings for the different data types
my %pack_for = (
	char   => 'c', 'unsigned char' => 'C',
	double => 'd',
	float  => 'f',
	'int'  => 'i', 'unsigned int' => 'I',
	long   => 'l', 'unsigned long' => 'L',
	short  => 's', 'unsigned short' => 'S',
	# Note, this must be the Perl internal representation of IV because the
	# *input* will ultimately be an IV. Using P or p screws things up for some
	# reason that I don't quite understand. And since I don't understand it,
	# this could may not actually work correctly on all platforms or for all
	# compilers.
	'*'    => 'j',
);
# Perl-side unpack strings for unpacking the return values
my %unpack_for = %pack_for;

# Add 'q' if the platform supports it
eval {
	# This will croak if 'q' is not supported:
	my $foo = pack 'q', 0;
	$pack_for{'long long'} = 'q';
	$pack_for{'unsigned long long'} = 'Q';
};

# Maps from the C-type to the data type's size, in bytes.
my %sizeof = map {
	my $data = pack $pack_for{$_}, 0;
	$_ => length($data)
} (keys %pack_for);


### XXX at some point create an API for adding new types XXX ###



sub preprocess {
	my (undef, $state, $is_lean, $callable_package) = @_;
	$callable_package = __PACKAGE__ unless defined $callable_package;
	
	# Build a replacement string of the same length
	my $package_string_length = length($callable_package);
	my $replacement_string = $callable_package;
	substr($replacement_string, 0, 2, '/*');
	substr($replacement_string, -2, 2, '*/');
	
	# Look through all the code blocks for the callable package
	my $to_add_to_foot = '';
	# This regex declares what we're looking for. It picks up where the last
	# search left off for reasons of efficiency:
	my $callable_regex = qr/\G.*?\b(?=$callable_package\b)/s;
	for my $section (qw(Head Body Foot)) {
		my $code = $state->code($section);
		pos($code) = 0;
		while ($code =~ m/$callable_regex/g) {
			my $initial_pos = pos($code);# - $package_string_length;
			# Replace the symbol so repeated regexes don't pick it up
			substr($code, $initial_pos, $package_string_length,
				$replacement_string);
			# Reset the position
			pos($code) = $initial_pos + $package_string_length;
			
			##########################################################
			# Extract the function signature and build function hash #
			##########################################################
			
			# Make sure that the string following the callable symbol is
			# parseable
			if (not eval { $code =~ $callable_package->function_parse_regex } ) {
				my $to_croak = "Could not identify $callable_package function declaration or definition in the vicinity of \n"
					. substr($code, pos($code), pos($code) + 100) . "\n";
				$to_croak .= "Reason: $@" if $@;
				croak($to_croak);
			}
			
			my ($return_type, @arg_types) = @matched_types;
			my ($function_name, @arg_names) = @matched_names;
			my $function_hashref = $state->{Callable}{$function_name} = {
				name        => $function_name,
				return_type => $return_type,
				arg_types   => \@arg_types,
				arg_names   => \@arg_names,
			};
			
			#################################################################
			# From here onward, everything operates on the function hashref #
			#################################################################
			
			$callable_package->clean_types($function_hashref);
			$callable_package->sort_args_by_binary_size($function_hashref);
			$to_add_to_foot .= $callable_package->build_C_invoker(
				$function_hashref);
			$callable_package->build_Perl_invoker($function_hashref);
		}
		# Reassign the code section, as we've removed the 
		$state->code($section) = $code;
	}
	$state->code('Foot') .= $to_add_to_foot;
}

sub function_parse_regex { $function_sig_re }

sub clean_types {
	#   package, hashref
	my (undef,   $function_hashref) = @_;
	for ($function_hashref->{return_type}, @{$function_hashref->{arg_types}}) {
		s/\bconst\b//g;	# remove 'const' indicators
		s{/[*].*?[*]/}{ }g;	# remove C-style comments
		s/^\s+//;			# remove initial spaces
		s/\s+$//;			# remove trailing spaces
		s/^\s{2,}/ /g;		# replace multiple spaces with single spaces
		s/[*]\s+(?=[*])/*/g;# smash asterisks together
		# make sure they don't have an unknown type
		croak("Unknown type $_") unless /[*]/ or /^void$/ or exists $sizeof{$_};
	}
}

sub sort_args_by_binary_size {
	my (undef, $function_hashref) = @_;
	my $arg_names = $function_hashref->{arg_names};
	my $arg_types = $function_hashref->{arg_types};
	
	# Calculate the argument sizes so we can put them in order of
	# decreasing size
	my @arg_sizes
		= map { /\*/ ? $sizeof{'*'} : $sizeof{$_} } @$arg_types;
	
	# Build the sorted argument array-of-arrays in descending order of size
	my @args = 
		sort {
			# This goes against PBP, which would say I should use reverse()
			# after the sort. However, I do it this way so that the order of
			# arguments that are the same size is preserved.
			$b->{size} <=> $a->{size}
		}
		map {
			+{
				name => $arg_names->[$_],
				type => $arg_types->[$_],
				size => $arg_sizes[$_]
			},
		}
		(0 .. $#$arg_types);
	
	# Set the sorted lists
	$function_hashref->{sorted_names} = [map $_->{name}, @args];
	$function_hashref->{sorted_types} = [map $_->{type}, @args];
	$function_hashref->{sorted_sizes} = [map $_->{size}, @args];
}

sub build_C_invoker {
	my (undef, $funchash) = @_;
	my $function_name = $funchash->{name};
	
	# Note, this signature must be coordinated with the typedef in
	# Callable.xs!!
	my $C_invoker = C::TinyCompiler::line_number(__LINE__) . "
		void _${function_name}_invoker(char * packlist, char * returnlist) {";
		
		# Unpack each argument (in order of descending sizeof)
		for my $i (0 .. $#{$funchash->{sorted_types}}) {
			my $type = $funchash->{sorted_types}[$i];
			my $var = $funchash->{sorted_names}[$i];
			my $size = $funchash->{sorted_sizes}[$i];
			$C_invoker .= C::TinyCompiler::line_number(__LINE__) . "
				$type $var = *(($type *)packlist);
				packlist += $size;
			";
		}
		# Call the function and get the return value
		my $return_lval = $return_lvals{$funchash->{return_type}};
		my $return_pack = $return_packs{$funchash->{return_type}};
		$C_invoker .= C::TinyCompiler::line_number(__LINE__) . "
			/* Call the function and pack the returned results if
			 * appropriate */
			$return_lval $function_name(" . join(', ', @{$funchash->{arg_names}}) . ");
			$return_pack;
		}";
	
	return $funchash->{C_invoker} = $C_invoker;
}

# Build and store the string that we will eval to get the
# Perl-callable subref. I use a string eval so that I can
# essentially perform loop unrolling in the argument handling,
# which buys me call-time speed at the one-time cost of a string
# eval. This also prevents memory leaks due to circular
# references.

use Scalar::Util;
sub build_Perl_invoker {
	my (undef, $funchash) = @_;
	my $function_name = $funchash->{name};
	my $return_type = $funchash->{return_type};
	
	# Construct a few values for interpolation. The list of arguments can be
	# unpacked on the Perl side, in the same order as the C function
	# definition.
	my $arg_list_string = '$' . join(', $', @{$funchash->{arg_names}});
	my $N_args = scalar(@{$funchash->{arg_names}});
	my $invoker_name = '_' . $funchash->{name} . '_invoker';
	my $pack_string = '';
	
	$funchash->{subref_string} = C::TinyCompiler::line_number(__LINE__) . "
		my \$func_ref = \$self->get_symbol('$invoker_name');
		sub {
			# Make sure we have enough arguments
			croak('$function_name expects $N_args arguments')
				unless \@_ == $N_args;
			my ($arg_list_string) = \@_;
			
			# Build the list of values to pack. Arguments are packed in order
			# of descending size in bytes, not necessarily the specified
			# argument order.
			my \@to_pack;
		";
	
	for my $i (0 .. $#{$funchash->{sorted_names}}) {
		# Get this argument's C type, perl-side name, and pack letter
		my $arg_name = '$' . $funchash->{sorted_names}[$i];
		my $arg_type = $funchash->{sorted_types}[$i];
		# Special-case handling for pointers, of course
		if ($arg_type =~ /[*]/) {
			$pack_string .= $pack_for{'*'};
		}
		else {
			$pack_string .= $pack_for{$arg_type};
		}
		
		# We have three general cases. SV*, other pointers, and
		# finally normal values. XXX make this more extensible!!!
		if ($arg_type =~ /SV\s*[*](?=$|[^*])/) {  # SV *
			$funchash->{subref_string} .= C::TinyCompiler::line_number(__LINE__) . "
				# SV * allows for custom handling; otherwise it must
				# be a reference!
				croak('Argument for $arg_name must be a refrence!')
					unless ref($arg_name);
				push \@to_pack,
					eval { ${arg_name}->can('pack_as') }
					? ${arg_name}->pack_as('$arg_type')
					: Scalar::Util::refaddr($arg_name);
				";
		}
		elsif ($arg_type =~ /\*/) {  # other pointers
			$funchash->{subref_string} .= C::TinyCompiler::line_number(__LINE__) . "
				# regular pointer allows for custom handling; otherwise it
				# must be an int or a ref. The int is packed as the pointer;
				# the PVx of the ref is packed as the pointer.
				push \@to_pack,
					eval { ${arg_name}->can('pack_as') }
					? ${arg_name}->pack_as('$arg_type')
					: C::TinyCompiler::Callable::_get_pointer_address($arg_name);
				";
		}
		else {  # generic pack
			$funchash->{subref_string} .= C::TinyCompiler::line_number(__LINE__) . "
				push \@to_pack,
					eval { ${arg_name}->can('pack_as') }
					? ${arg_name}->pack_as('$arg_type')
					: $arg_name;
				";
		}
	}
	
	# Now build the buffer to hold the return value
	my ($return_builder, $return_code);
	if (exists $unpack_for{$return_type}) {
		$return_builder = C::TinyCompiler::line_number(__LINE__) . "
			# Allocate return-type memory
			my \$return = pack('$pack_for{$return_type}', 0);
		";
		$return_code = C::TinyCompiler::line_number(__LINE__) . "
			return unpack '$unpack_for{$return_type}', \$return;
		";
	}
	else {
		$return_builder = C::TinyCompiler::line_number(__LINE__) . "
			# No return data; send in an empty memory buffer
			my \$return = '';
		";
		$return_code = '';
	}
	
	# Finally, build the end of the function definition that invokes the
	# call, unpacks the return value (if appropriate), and returns the
	# return value.
	$funchash->{subref_string} .= $return_builder
		. C::TinyCompiler::line_number(__LINE__) . "
		# Pack the args and invoke it!
		my \$packed_args = pack '$pack_string', \@to_pack;
		C::TinyCompiler::Callable::_call_invoker(\$func_ref, \$packed_args, \$return);
		$return_code
	}";
}

sub C::TinyCompiler::get_callable_subref {
	my ($self, $function_name) = @_;
	$self->has_compiled
		or croak('Cannot retrieve a callable function before compiling');
	
	croak("Unknown function $function_name")
		unless exists $self->{Callable}{$function_name};
	croak("No subref string for $function_name")
		unless exists $self->{Callable}{$function_name}{subref_string};
	my $subref = eval $self->{Callable}{$function_name}{subref_string};
	croak($@) if $@;
	return $subref;
}

1;

__END__

=head1 NAME

C::TinyCompiler::Callable - A C::TinyCompiler-based foreign function interface, i.e. C-functions
callable from Perl

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::TinyCompiler;
 
 # Make a few functions we can invoke from Perl:
 my $context = C::TinyCompiler->new('::Callable');
 $context->code('Body') = q{
     
     /* All Perl-callable functions should have
      * this string placed immediately before the
      * function declaration or definition: */
     C::TinyCompiler::Callable
     double positive_pow (double value, int exponent) {
         double to_return = 1;
         while (exponent --> 0) to_return *= value;
         return to_return;
     }
     
     C::TinyCompiler::Callable
     double my_sum (double * list, int length) {
         int i;
         double to_return = 0;
         for (i = 0; i < length; i++) {
             to_return += list[i];
         }
         return to_return;
     }
 };
 $context->compile;
 
 # Retrieve the function references:
 my $pow_subref = $context->get_callable_subref('positive_pow');
 my $sum_subref = $context->get_callable_subref('my_sum');
 
 # Exercise the pow subref
 print "3.5 ** 4 is ", $pow_subref->(3.5, 4), "\n";
 
 # Exercise the list summation:
 my @values = map { rand() } (1..10);
 my $doubles_buffer = pack('d*', @values);
 print join(' + ', @values), " = ",
     $sum_subref->(\$doubles_buffer, scalar(@values));

=head1 DESCRIPTION

This module implements the machinery necessary to easily call C functions from
Perl with arbitrarily many arguments. The types of the arguments are a bit
restricted at the moment, but it nonetheless works for a fairly broad variety
of things. In particular, it handles pointers just fine.

Like all other C::TinyCompiler packages, you make this module available as a package to your
compiler state either by indicating it as an argument to your state's
constructor or by applying the package later:

 # Create compiler state with C::TinyCompiler::Callable
 my $compiler = C::TinyCompiler->new('C::TinyCompiler::Callable');
 # Slighly abbreviated:
 my $compiler = C::TinyCompiler->new('::Callable');
 
 # Adding it after construction:
 my $compiler = C::TinyCompiler->new;
 $compiler->apply_packages('C::TinyCompiler::Callable');

The primary operation of this package is to scan through your code, identify
functions for which you want to build Perl functions, and build the necessary
C and Perl code. You indicate which of your functions should have Perl
interfaces by preceding them "immediately" with the package name:

 $compiler->code('Body') .= q{
     /* This will have a Perl interface */
     C::TinyCompiler::Callable
     void do_something(int arg1, double arg2) {
         ...
     }
     
     /* This will not have a Perl interface */
     void something_else (double foo, int bar) {
         ...
     }
     
     C::TinyCompiler::Callable  /* Also has a Perl interface */
     void third_func(int arg1, double arg2) {
         ...
     }
     
     /* comments among arguments is even ok */
     C::TinyCompiler::Callable
     void get_height_and_temp (
         /* Input: grid, location on the grid, and time of day */
         grid * my_grid, int x, int y, int time,
         /* Output: height and temperature of that position at that time */
         double * height, double * temperature
     ) {
         ...
     }

 };

The extraction parser does not care about whitespace, and is smart enough to
consider classic C-style comments (i.e. C</* comment */> but not C<// comment>)
as whitespace. This is true even within the function's arguments (i.e.
C<get_height_and_temp>) and between the Callable declaration and the function
declaration (i.e. C<third_func>).

Just before your code is run through the preprocessor, each function marked as
callable will be examined and a new C-level invocation function with a standard
argument layout will be added to the C<Foot> section. Also, the text for a Perl
function that knows the name of the C-level invocation function and knows how to
invoke it will be generated.

After you have compiled your code, you can obtain a Perl subref that invokes
your code by calling the C<get_callable_subref> method, supplying the function's
name. You can then invoke this method with your Perl arguments.

=head2 Basic Usage

The basic usage was already demonstrated in the Synopsis. If you use basic C
types, you should be able to just put C<C::TinyCompiler::Callable> before the function
declaration and you will be able to invoke your code from Perl in the obvious
way.

=head2 Working with pointers and C-level arrays

There are many ways that your Perl code might refer to arbitrary C data. One is
to have a Perl scalar whose integer value is the pointer address. Another is
to have the actual binary data stored in a Perl's PV slot, which is ordinarily
reserved for the string portion of the scalar. Since there is no clean way to
ascertain your scalar's provenance, C::TinyCompiler::Callable introduces the following
convention: if your scalar is a I<reference>, it assumes that the PV slot of the
I<referent> is a binary blob, and uses I<the address of that PV slot> as the
argument for a pointer. If your scalar is I<not a reference>, it assumes that
the I<IV slot> of I<your scalar> is a pointer address.

How does this work in practice? If you need to pass a string to your C code,
pass a I<reference> to the actual variable holding the data instead of passing
the variable itself:

 my $is_legit = $confirm_id->(\$user_id, \$user_password);
 #                            ^          ^
 # note reference             |          |

Similarly, if you pack a collection of data, you pass a reference to that
packed collection:

 my $packed_data = pack 'd*', @values;
 my $sum = $sum_data->(\$packed_data, scalar(@values));
 #                     ^
 # note referece       |

If you are an XS module writer and you want to allow somebody to get a hold of
a pointer to some data so they can manipulate it, you simply use C<PTR2IV>:

 /* in XS */
 IV
 get_pointer_for_array(self)
     SV * self
     CODE:
         ...
         RETVAL = PTR2IV(data_array);;
     OUTPUT:
         RETVAL

The resulting scalar will be perfect for sending to a function that expects a
pointer:

 my $data_ptr = $obj->get_pointer_for_array;
 my $length = $obj->length;
 my $sum = $sum_data->($data_ptr, $length);
 #                     ^
 # No reference!       |

=head2 Working with Perl-level objects

If you have Perl objects with data that you want to pass to a Callable
function, you can add the C<pack_as> method to your class to make life easier.
When your function gets an object, it will ask it if it can pack as the needed
type, such as C<int> or C<double *>. This way your object can present meaningful
data when used as an argument.

Assuming the ficticious object mentioned in the previous section holds an array
of doubles, one could implement a C<pack_as> method for tha class like so:

 sub pack_as {
     my ($self, $type) = @_;
     return $self->length if $type eq 'int';
     return $self->get_pointer_for_array
         if $type =~ /^double\s*[*]$/;
     croak('Foo can only be cast by C::TinyCompiler::Callable as a double* or int');
 }

Then the user could invoke the C<my_sum> function from the synopsis like so:

 my $sum = $my_sum_subref->($obj, $obj);

=head2 Caveats about Speed

This is an interface to C::TinyCompiler, and the resulting code compiles down to C code.
However, the code generated this way still has to jump through a lot of hoops.

I have tried to optimize the generated code as much as possible, but the path
from your Perl invocation of the generated subref to your actual C code
involves: (1) invoking the subref with your arguments, which goes on to
(2) unpack those arguments from C<@_>, (3) ask those arguments if they are
objects and know how to cast themselves to the required C type, and if not use a
default casting mechanism, (4) C<pack> all of the arguments into a single C
binary buffer, (5) build a return binary buffer, (6) call an XS "trampoline"
that calls the C wrapper with the input and output binary buffers, which
(7) unpacks the binary input buffer into C variables, (8) invokes the original
function with the unpacked C variables, (9) packs the return value into the
supplied binary return buffer and returns (it's actually a void function),
bringing us back to the subref which (10) unpacks the binary return buffer and
returns the value.

Contrast those steps with the steps needed for calling a simple xsub wrapper.
The steps involve (1) invoking the xsub with your arguments in Perl which
(2) unpacks the stack in your XS/C code, (3) invokes the original function with
the unpacked C variables, and (4) packs the return value(s) into SVs and places
them on the return stack.

In short, don't use this sort of functionality to add two integers. If you need
to perform complicated time stepping on a mesh, though, the extra overhead of
the function invocation will be relatively innocuous.

=head1 AUTHOR

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests at the project's main github page:
L<http://github.com/run4flat/perl-TCC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::TinyCompiler::Callable

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

=head1 SEE ALSO

There are a number of modules or tools that do something similar to what
C::TinyCompiler::Callable does. All of these modules use another compiler to generate the
object code in use, so they will present tradeoffs in compile time and
execution time compared with C::TinyCompiler::Callable.

L<C::TinyCompiler::Perl> pulls in all of the Perl headers, which in principle would allow
you to write your own Perl-callable C functions that manipulate the stack and
everything. Of course, that is not documented and it's likely to be quite
verbose, so it's not for the faint of heart. But in principle, that mechanism
provides another way to generate hooks so you can call C functions from Perl.

For a runtime foreign function interface, see L<FFI::Raw>, which mostly
supersedes L<FFI> (though the latter might be worth looking into). This module
uses assembly to build a C stack and then directly fire your C function.
Building the stack takes a little more effort on your part, but those details
can easily be encapsulated in a Perl-side wrapper. The only reason I didn't
use that module as this module's C function caller is that it is not (yet) as
general as I would like and I didn't want to introduce another nontrivial
dependency. 

A more powerful means for building C functions and calling them from Perl is
L<Inline::C>. This has the full power of XS, and the full optimization of your
local compiler, but is not designed to quickly compile. Generally, I find that
L<Inline::C> is a great means for prototyping my XS code, but the assumption is
that eventually the codebase will reach a stable state. If you need to
dynamically generate lots of different C functions throughout your code's
execution, the compiler invocation overhead of L<Inline::C> will likely not pay
off compared to the speed of tcc's compilation.

If your goal is to write a stable set of C functions that can be called from
Perl, you should ultimately look into Perl's C interface layer, L<perlxs>. XS is
generally meant to be used in the context of a module or suite of modules, and
it is nicely wrapped by L<Inline::C> (and more basically by L<Inline::XS>).
If you do not need to generate C code on the fly, this is the best means for
writing code that quickly invokes and executes. The Perl hooks into your code
will be the most direct of all of these options, and the generated object code
will be optimized by your compiler in ways that tcc likely will not be.

=head1 LICENSE AND COPYRIGHT

Portions of this module's code are copyright (c) 2013 Northwestern University.

Portions of this module's code are copyright (c) 2013 Dickinson College.

This module's documentation is copyright (c) 2013 David Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
