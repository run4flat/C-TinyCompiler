#!perl
# A test to check that include behavior works correctly

use 5.006;
use strict;
use warnings;
use Test::More tests => 9;

use inc::Capture;
use File::Spec;
use File::Path qw(make_path remove_tree);

sub build_test_header {
	my @path = @_;
	my $filename = pop @path;
	
	# Make sure the directory exists:
	make_path(File::Spec->catdir(@path));
	
	# Generate the header file:
	#my $full_file = File::Spec->catdir(@path, $filename); <-- not cross platform, doesn't interpolate!
	my $full_file = join('/', @path, $filename);
	open my $out_fh, '>', $full_file or die "Could not create file $full_file";
	print $out_fh qq{
		#ifndef TO_PRINT
			#define TO_PRINT "$full_file"
		#endif
	};
	close $out_fh;
}

######## test build_test_header and presence of '.' double-quote include path: 1
build_test_header qw(foo bar.h);

my $results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

# Test '.' include directory
my $context= C::TinyCompiler->new;
$context->code('Body') = q{
	#include "foo/bar.h"
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
# Call the compiled function:
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.bar\.h$/
	, "build_test_header works; '.' is in double-quote include dirs");
remove_tree('foo');

############################################### make sure that '.' is the cwd: 1
build_test_header qw(foo bar.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
$context->code('Body') = q{
	#include "bar.h"
	void test_func() {
		printf(TO_PRINT);
	}
};
chdir 'foo';		# change cwd
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.bar\.h$/
	, "'.' is the working directory when compile is invoked");
remove_tree('foo');

#################### check default angle-bracket include does not contain '.': 1
build_test_header qw(foo bar.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
$context->code('Body') = q{
	#include <foo/bar.h>
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/'foo.bar\.h' not found/
	, "default path does not include '.'");
remove_tree('foo');

############################## double-quotes checks check path before syspath: 1
build_test_header qw(foo baz.h);
build_test_header qw(foo bar baz.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
$context->add_include_paths('foo');
use File::Spec;
$context->add_sysinclude_paths(File::Spec->catdir('foo', 'bar'));
$context->code('Body') = q{
	#include "baz.h"
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.baz\.h$/
	, 'include path comes before syspath when using double-quotes');
remove_tree('foo');

#################### double-quotes checks include path, then sys-include path: 1
build_test_header qw(foo bar.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
$context->add_sysinclude_paths('foo');
$context->code('Body') = q{
	#include "bar.h"
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.bar\.h$/
	, 'double quote includes use syspath in addition to path');
remove_tree('foo');

################### angle-brackets check include path before sys-include path: 1
build_test_header qw(foo baz.h);
build_test_header qw(foo bar baz.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
use File::Spec;
$context->add_sysinclude_paths('foo');
$context->add_include_paths(File::Spec->catdir('foo', 'bar'));
$context->code('Body') = q{
	#include <baz.h>
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.bar.baz\.h$/
	, 'angle-bracket check include path before sys-include path');
remove_tree('foo');

###################################### angle brackets use '.' if it's in path: 1
build_test_header qw(foo bar.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
$context->add_include_paths('.');
$context->code('Body') = q{
	#include <foo/bar.h>
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.bar\.h$/
	, "angle brackets use '.' if it's in path");
remove_tree('foo');

###################################################### Order of paths is FIFO: 1
build_test_header qw(foo bar.h);
build_test_header qw(foo baz bar.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
use File::Spec;
$context->add_include_paths(
	'foo',
	File::Spec->catdir('foo', 'baz'),
);
$context->code('Body') = q{
	#include "bar.h"
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.bar\.h$/
	, 'First include directory added is the first checked');
remove_tree('foo');

########################### adding nonexistent directory doesn't break things: 1
build_test_header qw(foo bar.h);

$results = Capture::it(<<'TEST_CODE');
use C::TinyCompiler;

my $context= C::TinyCompiler->new;
$context->add_include_paths (qw(blarg foo));

$context->code('Body') = q{
	#include "bar.h"
	void test_func() {
		printf(TO_PRINT);
	}
};
$context->compile;
$context->call_void_function('test_func');

TEST_CODE

like($results, qr/^foo.bar\.h$/
	, 'nonexistent directories do not cause trouble');
remove_tree('foo');
