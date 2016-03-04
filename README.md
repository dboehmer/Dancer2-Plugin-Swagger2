# NAME

Dancer2::Plugin::Swagger2 - A Dancer2 plugin for creating routes from a Swagger2 spec

# VERSION

version 0.001

## Debugging

To see some more debug messages on STDERR set environment variable `SWAGGER2_DEBUG`
to a true value.

## swagger2( url => $url, ... )

Import routes from Swagger file. Named arguments:

- `url`: URL to passed to `Swagger2` module
- `controller_factory`: custom callback generator/finder that returns callbacks to routes
- `validate_spec`: boolish value (default: true) telling if Swagger2 file shall be validated by official Swagger specification
- `validate_requests`: boolish value (default: same as `validate_spec`) telling if HTTP requests shall be validated by loaded specification (needs `validate_spec` to be true)
- `validate_responses`: boolish value (default: same as `validate_spec`) telling if HTTP responses shall be validated by loaded specification (needs `validate_spec` to be true)

## default\_controller\_factory

Default method for finding a callback for a given `operationId`. Can be
overriden by the `controller_factory` argument to `swagger2` or config option.

The default uses the `controller` argument/config option or the name of
the app (possibly with `::Controller` appended). If the `operationId`
looks like a Perl module the module name is tried under the namespace
mentioned above and as a top level module name.

The module warns as long as controller modules or methods can't be found
and returns a coderef on the first match.

# AUTHORS

- Daniel Böhmer &lt;dboehmer@cpan.org>
- Tina Müller &lt;cpan2@tinita.de>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Daniel Böhmer.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
