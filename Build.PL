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
        'Alien::TinyCC' => 0.03,
	},
    build_requires => {
        'Test::More' => 0.88,
        'Alien::TinyCC' => 0.03,
        'Test::Exception' => 0,
        'Test::Warn' => 0,
    },
    requires => {
        'perl' => 5.010,
        'Alien::TinyCC' => 0.03,
    },
	needs_compiler => 1,
	dynamic_config => 1,
	include_dirs => [Alien::TinyCC->libtcc_include_path, '.'],
	extra_linker_flags => [Alien::TinyCC->MB_linker_flags],
	meta_merge => {
		resources  => {
			repository => "http://github.com/run4flat/perl-TCC",
			bugtracker => "http://github.com/run4flat/perl-TCC/issues",
		},
		no_index => {
			file      => [ 'README.pod' ],
		},
	},
);

$builder->create_build_script();
