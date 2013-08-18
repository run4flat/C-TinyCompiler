#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'C::TinyCompiler' ) or BAIL_OUT('Unable to load C::TinyCompiler!');
}

diag( "Testing C::TinyCompiler $C::TinyCompiler::VERSION, Perl $], $^X" );
