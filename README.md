# NAME

PerlSwagger - Swagger 2.0 API Service Framework

# SYNOPSIS

    use PerlSwagger;
    PerlSwagger->to_app('swagger.yml');

# DESCRIPTION

PerlSwagger is a simple to use web framework for RESTful webservices described with an OpenAPI 2.0 (formerly known as Swagger 2.0) specification.

The framework parses the specification on startup and creates a PSGI compatible app from it, which can be used with plackup.

Before calling any route handler, it checks the given parameters and only gives valid ones to the handler. Simple handlers don't have to know they are running as a webservice, as they just get a HashRef containing all the parameters and may return a HashRef as response body.

Handlers for routes are specified with the "x-handler" key in specification, which is something like this "My::Api::Code->handler\_sub".

# METHODS

## to\_app

    my $plack_app = to_app($spec_filepath);

Create plack application from swagger spec file.
