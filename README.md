# NAME

PerlSwagger - Swagger 2.0 API Service Framework

# SYNOPSIS

## app.psgi

    use lib ".";
    use PerlSwagger;
    PerlSwagger->to_app('swagger.yml');

## swagger.yml

    ---
    swagger: "2.0"
    info:
      version: "1.0.0"
      title: "Simplest possible example"
      description: "Just the simplest possible example"
    consumes:
      - "application/json"
    produces:
      - "application/json"
    paths:
      /:
        get:
          description: "Hello World, what else?"
          x-handler: "example::API->index"
          responses:
            200:
              description: "All ok, Hello World!"
              schema:
                type: "object"
                  properties:
                    message:
                    type: "string"

## example/API.pm

    package example::API;

    sub index {
        return {
            message => "test",
        };
    }

    1;

# DESCRIPTION

<div>
    <a href="https://travis-ci.org/LittleFox94/PerlSwagger"><img src="https://travis-ci.org/LittleFox94/PerlSwagger.svg?branch=master"></a>
</div>

PerlSwagger is a simple to use web framework for RESTful webservices described with an OpenAPI 2.0 (formerly known as Swagger 2.0) specification.

The framework parses the specification on startup and creates a PSGI compatible app from it, which can be used with plackup.

Before calling any route handler, it checks the given parameters and only gives valid ones to the handler. Simple handlers don't have to know they are running as a webservice, as they just get a HashRef containing all the parameters and may return a HashRef as response body.

Handlers for routes are specified with the "x-handler" key in specification, which is something like this "My::Api::Code->handler\_sub".

# METHODS

## to\_app

    my $plack_app = to_app($spec_filepath);

Create plack application from swagger spec file.

# LINKS

- GitHub repository:

    https://github.com/LittleFox94/PerlSwagger

- OpenAPI 2.0 specification:

    https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md
