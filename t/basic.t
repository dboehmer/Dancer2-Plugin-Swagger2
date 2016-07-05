#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Requires 'YAML::XS';

plan tests => 5;

package MyApp::Controller::Foo;

sub bar { "Hello_World!"  }

sub baz { shift->send_file( \"Comment ca va", content_type => 'text/plain' ) }

package MyApp;

use Dancer2;
use Dancer2::Plugin::Swagger2;

swagger2( url => "data://main/swagger2.yaml" );

package main;

use HTTP::Request::Common;
use Plack::Test;

ok( my $app = MyApp->to_app );
my $test = Plack::Test->create($app);

my $res = $test->request( GET '/api/welcome' );
like $res->content => qr/hello.+world/i;
is $res->code      => 200;

$res = $test->request( GET '/api/bonjour' );
like $res->content => qr/comment ca va/i;
is $res->code      => 200;

__DATA__
@@ swagger2.yaml
---
swagger: "2.0"
info:
  title: Example API
  version: "1.0"
basePath: /api
paths:
  /welcome:
    get:
      operationId: Foo::bar
      responses:
        200:
          description: success
  /bonjour:
    get:
      operationId: Foo::baz
      responses:
        200:
          description: success
