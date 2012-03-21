use 5.006;
use strict;
use warnings;
use Module::Build;
use Devel::PPPort;

#### --( Make sure we can find libtcc )-- ####
# Consider using Devel::CheckLib for this:

my @dirs = qw(
/usr/local
/home/visitors/dcmertens
);

my $tcc_dir;
foreach (@dirs) {
    if (-f $_ . "/include/libtcc.h") {
        $tcc_dir = $_;
        last;
    }
}

if (not defined($tcc_dir)) {
    die "Cannot find tcc directory. This is probably because the logic for finding libtcc is too dumb.\n"
		. "Please edit Build.PL and put tcc's PREFIX in the \@dirs section";
}


#### --( Make sure we have ppport.h )-- ####

Devel::PPPort::WriteFile();


#### --( Make the builder )-- ####

my $builder = Module::Build->new(
    module_name         => 'TCC',
    license             => 'perl',
    dist_author         => q{David Mertens <dcmertens.perl@gmail.com>},
    dist_version_from   => 'lib/TCC.pm',
    build_requires => {
        'Test::More' => 0,
        'Devel::PPPort' => 0,
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'TCC-*', 'ppport.h' ],
    create_makefile_pl => 'traditional',
	needs_compiler => 1,
	include_dirs => ["$tcc_dir/include", '.'],
	extra_linker_flags => ["-L$tcc_dir/lib", '-ltcc'],
);

$builder->create_build_script();
