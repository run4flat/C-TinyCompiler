use 5.006;
use strict;
use warnings;
use Module::Build;

# Thank God, tcc provides a (non-documented) means for extracting the prefix!
my $tcc_dir = `tcc -print-search-dirs`;
# Croak if tcc is not in the path, or if we can't pick out the install location
die "Unable to locate tcc (or the print-search-dirs option is bad). Is tcc in your path?\n" if $!;
if ($tcc_dir =~ /install: (.*).lib.tcc.\n/) {
	$tcc_dir = $1;
	die "Extracted prefix from tcc, but can't find libtcc!\n"
		unless -f "$tcc_dir/include/libtcc.h";
}
else {
	die "Failed to get prefix from tcc:\n$tcc_dir"
}

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
	include_dirs => ["$tcc_dir/include", '.'],
	extra_linker_flags => ["-L$tcc_dir/lib", '-ltcc'],
);

$builder->create_build_script();
