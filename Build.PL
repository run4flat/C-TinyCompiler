use 5.006;
use strict;
use warnings;
use Module::Build;
use Alien::TinyCC;

#### --( Make sure we have ppport.h )-- ####

use Devel::PPPort;
Devel::PPPort::WriteFile();

#### --( Make the builder )-- ####

my $builder = Module::Build->new(
    module_name         => 'C::TinyCompiler',
    license             => 'perl',
    dist_author         => q{David Mertens <dcmertens.perl@gmail.com>},
	configure_requires => {
        'Devel::PPPort' => 0,
        'Alien::TinyCC' => 0,
	},
    build_requires => {
        'Test::More' => 0.88,
        'Alien::TinyCC' => 0,
    },
    requires => {
        'perl' => 5.010,
        'Alien::TinyCC' => 0,
    },
	needs_compiler => 1,
	dynamic_config => 1,
	include_dirs => [Alien::TinyCC->libtcc_include_path, '.'],
	extra_linker_flags => [Alien::TinyCC->MB_linker_flags],
);

$builder->create_build_script();
