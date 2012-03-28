#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'TCC' ) or BAIL_OUT('Unable to load TCC!');
}

diag( "Testing TCC $TCC::VERSION, Perl $], $^X" );
