use 5.006;
use strict;
use warnings;
use Module::Build;

# Thank God, tcc provides a (non-documented) means for extracting its
# installed location, i.e. the prefix!
my $tcc_search_dirs = `tcc -print-search-dirs`;
# Die if it's not in the path
die "Unable to locate tcc (or the print-search-dirs option is bad). Is tcc in your path?\n"
	if $! or $tcc_search_dirs =~ /'tcc' is not recognized as an internal/;
# Die if it didn't give useful information (for some other reason)
die "Failed to get prefix from tcc:\n$tcc_search_dirs"
	unless $tcc_search_dirs =~ /install: (.*)/;

# Construct the path to the lib. This is system-dependent.
my $tcc_prefix = $1;

# That only works on Windows; adjust for other systems
$tcc_prefix =~ s/(.*).lib.tcc./$1/ unless $^O =~ /MSWin/;

# Locate the libtcc header file
my $include_dir = $^O =~ /MSWin/ ? "$tcc_prefix/libtcc" : "$tcc_prefix/include";
die "Could not find libtcc header file in $include_dir"
	unless -f "$include_dir/libtcc.h";
# Locate the libtcc shared library
my $lib_dir = $tcc_prefix;
$lib_dir .= '/lib' unless $^O =~ /MSWin/;
die "Could not find libtcc shared library in $lib_dir"
	unless grep -f, glob("$lib_dir/libtcc.*");

END {
	if ($^O =~ /MSWin/ and not -f 'Build.bat') {
		print "
If you installed tcc from source, be sure to copy the contents of the
win32 directory to a location in your path. (Yeah, I really should create
an Alien module for TCC. I know, I know...)
";
	}
}

#### --( Make sure we have ppport.h )-- ####

use Devel::PPPort;
Devel::PPPort::WriteFile();

#### --( Make the builder )-- ####

my $builder = Module::Build->new(
    module_name         => 'TCC',
    license             => 'perl',
    dist_author         => q{David Mertens <dcmertens.perl@gmail.com>},
    dist_version_from   => 'lib/C/TinyCompiler.pm',
	configure_requires => {
        'Devel::PPPort' => 0,
	},
    build_requires => {
        'Test::More' => 0.88,
    },
    requires => {
        'perl' => 5.010,
    },
#    add_to_cleanup      => [ 'TCC-*'],
    create_makefile_pl => 'traditional',
	needs_compiler => 1,
	include_dirs => [$include_dir, '.'],
	extra_linker_flags => ["-L$lib_dir", '-ltcc'],
);

$builder->create_build_script();
