package Dancer2::Plugin::Swagger2;

use Dancer2 ':syntax';
use Dancer2::Plugin;
use Module::Load;
use Swagger2;

=head1 Dancer2::Plugin::Swagger2

=head2 Debugging

To see some more debug messages on STDERR set environment variable C<SWAGGER2_DEBUG>
to a true value.

=cut

sub DEBUG { !!$ENV{SWAGGER2_DEBUG} }

=head2 swagger2(url => $url, (cb => \&cb)?)

Import routes from Swagger file. Named arguments:

=over

=item C<url>: URL to passed to C<Swagger2> module

=item C<cb>: custom callback generator/finder that returns callbacks to routes

=item C<validate_spec>: boolish value (default: true) telling if Swagger2 file shall be validated by official Swagger specification

=item C<validate_input>: boolish value (default: same as C<validate_spec>) telling if HTTP requests shall be validated by loaded specification (needs C<validate_spec> to be true)

=item C<validate_output>: boolish value (default: same as C<validate_spec>) telling if HTTP responses shall be validated by loaded specification (needs C<validate_spec> to be true)

=back

=cut

register swagger2 => sub {
    my ( $dsl, %args ) = @_;
    my $conf = plugin_setting;

    # get arguments/config values/defaults
    my $cb = $args{cb} || $conf->{cb} || \&_default_cb;
    my $url = $args{url} or die "argument 'url' missing";
    my $validate_spec =
        exists $args{validate_spec}   ? !!$args{validate_spec}
      : exists $conf->{validate_spec} ? !!$conf->{validate_spec}
      :                                 1;
    my $validate_input =
        exists $args{validate_input}   ? !!$args{validate_input}
      : exists $conf->{validate_input} ? !!$conf->{validate_input}
      :                                  $validate_spec;
    my $validate_output =
        exists $args{validate_output}   ? !!$args{validate_output}
      : exists $conf->{validate_output} ? !!$conf->{validate_output}
      :                                   $validate_spec;

    if ( ( $validate_input or $validate_output ) and not $validate_spec ) {
        die "Cannot validate input/output with spec assured to be true";
    }

    # parse Swagger2 file
    my $swagger2 = Swagger2->new($url)->expand;

    if ($validate_spec) {
        my @errors = $swagger2->validate;
        @errors and die join "\n" => "Swagger2: Invalid spec:", @errors;
    }

    my $basePath = $swagger2->api_spec->get('/basePath');
    my $paths    = $swagger2->api_spec->get('/paths');    # TODO might be undef?

    while ( my ( $path => $path_spec ) = each %$paths ) {
        my $dancer2_path = $path;

        # adapt Swagger2 syntax for URL path arguments to Dancer2 syntax
        # '/path/{argument}' -> '/path/:argument'
        $dancer2_path =~ s/\{([^{}]+?)\}/:$1/g;

        while ( my ( $method => $method_spec ) = each %$path_spec ) {
            my $coderef = $cb->( $conf, $dsl, \%args, $method_spec ) or next;

            $basePath and $dancer2_path = $basePath . $dancer2_path;

            DEBUG and warn "Add route $method $dancer2_path";

            my $params = $method_spec->{parameters};

            # Dancer2 DSL keyword is different from HTTP method
            $method eq 'delete' and $method = 'del';

            $dsl->$method(
                $dancer2_path => sub {

                    $validate_input
                      and _validate_input( $method_spec, $dsl->request );

                    my $response = $coderef->();

                    $validate_output and _validate_output(...);

                    return $response;
                }
            );
        }
    }
};

register_plugin;

sub _validate_input {
    my ( $method_spec, $request ) = @_;

    my @errors;
    my $validator = Swagger2::SchemaValidator->new();

    for my $parameter_spec ( @{ $method_spec->{parameters} } ) {
        my $in       = $parameter_spec->{in};
        my $name     = $parameter_spec->{name};
        my $required = $parameter_spec->{required};

        if ( $in eq 'body' ) {    # complex data structure in HTTP body
            my $input  = $request->data;
            my $schema = $parameter_spec->{schema};

            push @errors, $validator->validate_input( $input, $schema );
        }
        else {    # simple key-value-pair in HTTP header/query/path/form
            my $type = $parameter_spec->{type};
            my @values;

            if ( $in eq 'header' ) {
                @values = $request->header($name);
            }
            elsif ( $in eq 'query' ) {
                @values = $request->query_parameters->get_all($name);
            }
            elsif ( $in eq 'path' ) {
                @values = $request->route_parameters->get_all($name);
            }
            elsif ( $in eq 'formData' ) {
                @values = $request->body_parameters->get_all($name);
            }
            else { die "Unknown value for property 'in' of parameter '$name'" }

            # TODO align error messages to output style of SchemaValidator
            if ( @values == 0 and $required ) {
                $required and push @errors, "No value for parameter '$name'";
                next;
            }
            elsif ( @values > 1 ) {
                push @errors, "Multiple values for parameter '$name'";
                next;
            }

            my $value  = $values[0];
            my $input  = { $name => $value };
            my $schema = {
                properties => { $name => $parameter_spec },
                required => [ $required ? ($name) : () ],
            };

            push @errors, $validator->validate_input( $input, $schema );
        }
    }

    return @errors;
}

=head2 default_cb

Default method for finding a callback for a given C<operationId>. Can be
overriden by the C<cb> argument to C<swagger2> or config option.

The default uses the C<controller> argument/config option or the name of
the app (possibly with C<::Controller> appended). If the C<operationId>
looks like a Perl module the module name is tried under the namespace
mentioned above and as a top level module name.

The module warns as long as controller modules or methods can't be found
and returns a coderef on the first match.

=cut

sub _default_cb {
    my ( $conf, $dsl, $args, $method_spec ) = @_;

    # from Dancer2 app
    my $namespace = $args->{controller} || $conf->{controller};
    my $app = $dsl->app->name;

    # from Swagger2 file
    my $module;
    my $method = $method_spec->{operationId};
    if ( $method =~ s/^(.+)::// ) {    # looks like Perl module
        $module = $1;
    }

    # different candidates possibly reflecting operationId
    my @controller_candidates = do {
        if ($namespace) {
            if ($module) { $namespace . '::' . $module, $module }
            else         { $namespace }
        }
        else {
            if ($module) {
                (                      # parens for better layout by Perl::Tidy
                    $app . '::' . $module,
                    $app . '::Controller::' . $module,
                    $module,           # maybe a top level module name?
                );
            }
            else { $app, $app . '::Controller' }
        }
    };

    # check candidates
    for my $controller (@controller_candidates) {
        eval { load $controller };
        if ($@) {
            if ( $@ =~ m/^Can't locate / ) {    # module doesn't exist
                DEBUG and warn "Can't load '$controller'";

                # don't do `next` here because controller could be
                # defined in other package ...
            }
            else {    # module doesn't compile
                die $@;
            }
        }

        my $cb = $controller->can($method);

        if ( not $cb ) {
            DEBUG and warn "Controller '$controller' can't '$method'";
            next;
        }

        # confirmed candidate, return coderef to controller method
        $cb and return $cb;
    }

    # none found
    warn "Can't find any handler for operationId '$method_spec->{operationId}'";
    return;
}

1;
