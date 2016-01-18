#!/usr/bin/env perl

use lib 'lib/';

use Test::Most tests => 1;

bail_on_fail;
use_ok 'Dancer2::Plugin::Swagger2';
