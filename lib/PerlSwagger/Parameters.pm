package PerlSwagger::Parameters;

sub new {
    my ($package, @parameters) = @_;

    my @path_params = ();
    my @body_params = ();

    for my $parameter (@parameters) {
        if($parameter->{in} eq 'body') {
            push(@body_params, $parameter);
        }
        elsif($parameter->{in} eq 'path') {
            push(@path_params, $parameter);
        }
        else {
            die('Unsupported parameter location: ' . $parameter->{in});
        }
    }

    return bless({
        path_params => \@path_params,
        body_params => \@body_params,
    }, $package);
}

sub check_required {
    my ($self, $params) = @_;

    my @param_names = map  { $_->{name} }
                      grep { $_->{required} }
                      @{$self->{path_params}},
                      @{$self->{body_params}};

    my $ok = 1;
    for my $name (@param_names) {
        if(!exists($params->{$name})) {
            $ok = 0;
        }
    }

    return $ok;
}

sub validate_param {
    ($self, $name, $value) = @_;

    my $param_spec = $self->_param_spec_by_name($name);

    if(!defined($param_spec)) {
        return -1;
    }

    my $validator = $self->can('_validate_' . $param_spec->{schema}->{type});

    if(!defined($validator)) {
        die('Unsupported type: ' . $param_spec->{schema}->{type});
    }

    return $validator->($self, $param_spec, $value);
}

sub filter_params {
    my ($self, $params) = @_;

    my $transformed_params = {};

    for my $name (keys %$params) {
        if($self->validate_param($name, $params->{$name})) {
            my $param_spec = $self->_param_spec_by_name($name);

            if($param_spec->{schema}->{type} eq 'boolean') {
                $transformed_params->{$name} = $params->{$name} == JSON::true;
            }
            else {
                $transformed_params->{$name} = $params->{$name};
            }
        }
    }

    return $transformed_params;
}

sub _param_spec_by_name {
    my ($self, $name) = @_;

    my ($param_spec) = grep { $_->{name} eq $name } @{$self->{body_params}};
    return $param_spec;
}

# XXX Complete this sub
sub _validate_object {
    my ($self, $param_spec, $value) = @_;

    if(ref($value) != 'HASH') {
        return 0;
    }

    return 1;
}

sub _validate_string {
    my ($self, $param_spec, $value) = @_;

    if(ref($value) eq '') {
        return 1;
    }
    else {
        return 0;
    }
}

1;
__END__
=pod

=head1 NAME

PerlSwagger::Parameters - parse and handle parameters

=head1 INSTANCE OBJECT

    $self = bless {
        path_params => [],
        body_params => [],
    };

Data documented in this chapter is provided as stable interface if only retrieved from the structure. Writing to this structure is not guaranted to work.

=head1 METHODS

=head2 validate_param

    my $result = $parameters->validate_param('id', 5);

Checks if the given parameter can have the given value.

Only parameters in body are searched for a parameter specification with the given name.

Return values:

=over 4

=item

-1 if the parameter does not exist in the spec

=item

0 if the parameter can not have the given value

=item

1 if the parameter can have the given value

=back

=cut
