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
die "Failed to get prefix from tcc:\n$tcc_dir"
	unless $tcc_search_dirs =~ /install: (.*)/;

# Construct the path to the lib. This is system-dependent.
my $tcc_prefix = $1;

# That only works on Windows; adjust for other systems
$tcc_prefix =~ s/(.*).lib.tcc./$1/ unless $^O !~ /MSWin/;

# Double-check
die "Extracted prefix from tcc, but can't find libtcc!\n"
	unless -f "$tcc_prefix/include/libtcc.h";

#### --( Make sure we have ppport.h )-- ####

use Devel::PPPort;
Devel::PPPort::WriteFile();

#### --( Make the builder )-- ####

my $builder = Module::Build->new(
    module_name         => 'TCC',
    license             => 'perl',
    dist_author         => q{David Mertens <dcmertens.perl@gmail.com>},
    dist_version_from   => 'lib/TCC.pm',
	configure_requires => {
        'Devel::PPPort' => 0,
	},
    build_requires => {
        'Test::More' => 0.88,
    },
    requires => {
        'perl' => 5.010,
    },
    add_to_cleanup      => [ 'TCC-*'],
    create_makefile_pl => 'traditional',
	needs_compiler => 1,
	include_dirs => ["$tcc_prefix/include", '.'],
	extra_linker_flags => ["-L$tcc_prefix/lib", '-ltcc'],
);

$builder->create_build_script();
