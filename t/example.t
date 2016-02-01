#!/usr/bin/env perl

use lib 'lib/';

use FindBin;
use Test::More;

package MyApp::Controller::Foo;

sub bar { "Hello world!" }

package MyApp;

use Dancer2;
use Dancer2::Plugin::Swagger2;

# TODO move example Swagger2 spec to DATA section
swagger2( url => Mojo::URL->new("$FindBin::Bin/example.yaml") );

package main;

use HTTP::Request::Common;
use Plack::Test;
use Test::More tests => 1;

my $app  = MyApp->to_app;
my $test = Plack::Test->create($app);

my $res = $test->request( GET '/foo/bar' );
is $res->code => 200;

