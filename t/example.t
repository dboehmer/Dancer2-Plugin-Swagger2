#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib/';

use FindBin;
use Test::More;

package MyApp::Controller::Foo;

sub bar { "Hello world!" }

package MyApp;

use Dancer2;
use Dancer2::Plugin::Swagger2;

swagger2( url => Mojo::URL->new("data://main/myApp.yaml") );

package main;

use HTTP::Request::Common;
use Plack::Test;
use Test::More tests => 1;

my $app  = MyApp->to_app;
my $test = Plack::Test->create($app);

my $res = $test->request( GET '/foo/bar' );
is $res->code => 200;

__DATA__
@@ myApp.yaml
---
swagger: "2.0"
info:
  title: Example API
  version: "1.0"
basePath: /foo
paths:
  /bar:
    get:
      operationId: Foo::bar
      responses:
        200:
          description: success
