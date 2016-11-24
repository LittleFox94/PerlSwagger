package PerlSwagger::PathBuilder;

use PerlSwagger::Parameters;

sub build {
    my ($package, $path, $path_spec) = @_;

    my @parameters = (
        defined $path_spec->{parameters} ? @{$path_spec->{parameters}} : (),
    );

    my @routes = ();

    for my $method (keys %{$path_spec}) {
        if($method eq 'parameters') {
            next;
        }

        my @method_parameters = (
            @parameters,
            defined $path_spec->{$method}->{parameters} ? @{$path_spec->{$method}->{parameters}} : (),
        );

        my $param_object = PerlSwagger::Parameters->new(@method_parameters);
        my $path_regex   = $package->make_path_regex($path, $param_object);
        my $x_handler    = $path_spec->{$method}->{'x-handler'};


        my $handler;
        if(defined($x_handler)) {
            my ($pkg, $sub)  = split(/->/, $x_handler);

            if(defined $pkg && defined $sub) {
                eval("use $pkg");
                $handler = $pkg->can($sub);
            }

            if (!defined($handler)) {
                warn 'Invalid handler for ' . uc($method) . ' ' . $path;
            }
        }

        push(@routes, {
            method     => $method,
            orig_path  => $path,
            path       => $path_regex,
            parameters => $param_object,
            handler    => $handler,
        });
    }

    return @routes;
}

sub make_path_regex {
    my ($package, $path, $params) = @_;

    for my $param (@{$params->{path_params}}) {
        my $param_type  = $param->{schema}->{type};
        my $param_regex = $param_type eq 'string'  ? '(.+)'
                        : $param_type eq 'integer' ? '([0-9]+)'
                        : $param_type eq 'number'  ? '([0-9]+\.?[0-9]*)'
                        : $param_type eq 'boolean' ? '(true|false)'
                        : die('Unsupported path parameter type: ' . $param_type);

        my $param_name = $param->{name};
        $path =~ s/\{$param_name\}/$param_regex/;
    }

    return qr~^$path$~;
}

1;
__END__
=pod

=head1 NAME

PerlSwagger::PathBuilder - Interpret path specification and build endpoints.

=cut
