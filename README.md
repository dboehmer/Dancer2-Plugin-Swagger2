# NAME

Dancer2::Plugin::Swagger2 - A Dancer2 plugin for creating routes from a Swagger2 spec

# VERSION

version 0.003

# SYNOPSIS

`example/my_app.pl`:

    #!/usr/bin/env perl

    use Dancer2;
    use Dancer2::Plugin::Swagger2;
    use Path::Tiny;

    swagger2( url => path(__FILE__)->parent->child('swagger2.yaml') );

    sub my_controller {
        return "Hello World!\n";
    }

    dance;

`example/swagger2.yaml`:

    ---
    swagger: "2.0"
    info:
      title: MyApp's API
      version: "1.0"
    basePath: /api
    paths:
      /welcome:
        get:
          operationId: my_controller
          responses:
            200:
              description: success

Then on the terminal run:

    perl my_app.pl
    curl http://localhost:3000/api/welcome

You'll find the example files displayed above in the distribution and repository.

# MIGRATING FROM DANCER1

If you've been using Dancer1 before you might know [Dancer::Plugin::Swagger](https://metacpan.org/pod/Dancer::Plugin::Swagger).
Please note that that module's workflow is completely different! It is about
creating the spec from the app. The module described in this text is about
reading the spec and creating parts of the app for you.

# DEBUGGING

To see some more debug messages on STDERR set environment variable `SWAGGER2_DEBUG`
to a true value.

# METHODS

## swagger2( url => $url, ... )

Import routes from Swagger file. Named arguments:

- `url`: URL to passed to [Swagger2](https://metacpan.org/pod/Swagger2) module
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

# SEE ALSO

- [Mojolicious::Plugin::Swagger2](https://metacpan.org/pod/Mojolicious::Plugin::Swagger2) A similar plugin for the [Mojolicious](https://metacpan.org/pod/Mojolicious) Web framework
- [http://swagger.io/](http://swagger.io/): Website of the Swagger alias OpenAPI Specification

# ACKNOWLEDGEMENT

This software has been developed with support from [STRATO](https://www.strato.com/).
In German: Diese Software wurde mit Unterstützung von [STRATO](https://www.strato.de/) entwickelt.

# AUTHORS

- Daniel Böhmer <dboehmer@cpan.org>
- Tina Müller <cpan2@tinita.de>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Daniel Böhmer.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
