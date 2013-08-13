package TCC::Callable;
use strict;
use warnings;
use parent 'TCC::package';
use Carp;

BEGIN {
	our $VERSION = '0.01';
	use XSLoader;
	XSLoader::load 'TCC::Callable', $VERSION;
}

sub apply {
	my (undef, $state, $callable_package) = @_;
	$callable_package = __PACKAGE__ unless defined $callable_package;
	# Make sure the package is a valid package name
	$callable_package =~ /^[_A-Za-z]\w+(?:::\w+)*$/
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
			(?{push @TCC::Callable::matched_types, $+})
		)
		
		# A name captures an identifier and stores the results on a stack
		(?<name>
			# Match an identifier
			((?&identifier))
			# Save the match
			(?{push @TCC::Callable::matched_names, $+})
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
				@TCC::Callable::matched_types = ();
				@TCC::Callable::matched_names = ();
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
	'*'    => 'p',
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
	
	# Build the sorted argument array-of-arrays
	my @args = 
		reverse
		sort {
			$a->{size} <=> $b->{size}
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
	my $C_invoker = TCC::line_number(__LINE__) . "
		void _${function_name}_invoker(char * packlist, char * returnlist) {";
		# Unpack each argument (in order of descending sizeof)
		for my $i (0 .. $#{$funchash->{sorted_types}}) {
			my $type = $funchash->{sorted_types}[$i];
			$C_invoker .= TCC::line_number(__LINE__) . "
				$type $funchash->{sorted_names}[$i] = *(($type *) packlist);
				packlist += $funchash->{sorted_sizes}[$i];
			";
		}
		# Call the function and get the return value
		my $return_lval = $return_lvals{$funchash->{return_type}};
		my $return_pack = $return_packs{$funchash->{return_type}};
		$C_invoker .= TCC::line_number(__LINE__) . "
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
	
	$funchash->{subref_string} = TCC::line_number(__LINE__) . "
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
			$funchash->{subref_string} .= TCC::line_number(__LINE__) . "
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
			$funchash->{subref_string} .= TCC::line_number(__LINE__) . "
				# regular pointer allows for custom handling; otherwise it
				# must be an int or a ref. The int is packed as the pointer;
				# the PVx of the ref is packed as the pointer.
				push \@to_pack,
					eval { ${arg_name}->can('pack_as') }
					? ${arg_name}->pack_as('$arg_type')
					: TCC::Callable::_get_pointer_address($arg_name);
		printf 'Perl-accessible address returned from _get_pointer_address pointer is %x\n', \$to_pack[-1];
				";
		}
		else {  # generic pack
			$funchash->{subref_string} .= TCC::line_number(__LINE__) . "
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
		$return_builder = TCC::line_number(__LINE__) . "
			# Allocate return-type memory
			my \$return = pack('$pack_for{$return_type}', 0);
		";
		$return_code = TCC::line_number(__LINE__) . "
			return unpack '$unpack_for{$return_type}', \$return;
		";
	}
	else {
		$return_builder = TCC::line_number(__LINE__) . "
			# No return data; send in an empty memory buffer
			my \$return = '';
		";
		$return_code = '';
	}
	
	# Finally, build the end of the function definition that invokes the
	# call, unpacks the return value (if appropriate), and returns the
	# return value.
	$funchash->{subref_string} .= $return_builder
		. TCC::line_number(__LINE__) . "
		# Pack the args and invoke it!
		my \$packed_args = pack '$pack_string', \@to_pack;
	#use Devel::Peek;
	#Dump(\\\$packed_args);
	my \@round_trip = unpack '$pack_string', \$packed_args;
	printf('round-trip pointer value is %x\n', \$round_trip[-1]);
		TCC::Callable::_call_invoker(\$func_ref, \$packed_args, \$return);
		$return_code
	}";
}

sub TCC::get_callable_subref {
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

TCC::Callable - build Perl-callable functions in C

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHORS

David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tcc at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TCC>.  I
will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TCC::StretchyBuffer

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

Sean Barett, of course, for creating such a simple but useful chunk of code, and
for putting that code in the public domain!

=head1 LICENSE AND COPYRIGHT

Sean Barett's original code is in the public domain. All modifications made by
David Mertens are Copyright 2012 Northwestern University.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
