#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use HTTP::Request::Common;
use Plack::Test;
use Test::More tests => 3;

$ENV{DANCER_APPHANDLER} = 'PSGI';
ok( my $app = require "$FindBin::Bin/../example/my_app.pl" );

my $test = Plack::Test->create($app);

my $res = $test->request( GET '/api/welcome' );
like $res->content => qr/hello.+world/i;
is $res->code      => 200;

