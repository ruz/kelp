# NAME

Kelp - A web framework light, yet rich in nutrients.

# SYNOPSIS

File `MyWebApp.pm`:

```perl
package MyWebApp;
use base 'Kelp';

sub build {
    my $self = shift;
    my $r = $self->routes;
    $r->add( "/hello", sub { "Hello, world!" } );
    $r->add( '/hello/:name', 'greet' );
}

sub greet {
    my ( $self, $name ) = @_;
    "Hello, $name!";
}

1;
```

File `app.psgi`:

```perl
use MyWebApp;
my $app = MyWebApp->new;
$app->run;
```

Or, for quick prototyping use [Kelp::Less](http://search.cpan.org/perldoc?Kelp::Less):

```perl
use Kelp::Less;

get '/hello/?name' => sub {
    my ( $self, $name ) = @_;
    "Hello " . $name // 'world';
};

run;
```

# DESCRIPTION

If you're going to be deploying a Perl based web application, chances are that
you will be using Plack. Plack has almost all necessary tools to create and
maintain a healthy web app. Tons of middleware is written for it, and there are
several very well tested high performance preforking servers, such as Starman.

Plack, however, is not a web framework, hence its creators have intentionally
omitted adding certain components. This is where Kelp gets to shine. It provides
a layer on top of Plack and puts everything together into a complete web
framework.

Kelp provides:

- __Advanced Routing__. Create intricate, yet simple ways to capture HTTP requests
and route them to their designated code. Use explicit and optional named
placeholders, wildcards, or just regular expressions.
- __Flexible Configuration__. Use different configuration file for each
environment, e.g. development, deployment, etc. Merge a temporary configuration
into your current one for testing and debugging purposes.
- __Enhanced Logging__. Log messages at different levels of emergency. Log to a
file, screen, or anything supported by Log::Dispatcher.
- __Powerful Rendering__. Use the built-in auto-rendering logic, or the template
module of your choice to return rich text, html and JSON responses.
- __JSON encoder/decoder__. If you're serious about your back-end code. Kelp comes
with JSON, but you can easily plug in JSON::XS or any decoder of your choice.
- __Extendable Core__. Kelp uses pluggable modules for everything. This allows
anyone to add a module for a custom interface. Writing Kelp modules is a
pleasant and fulfilling activity.
- __Sleek Testing__. Kelp takes Plack::Test and wraps it in an object oriented
class of convenience methods. Testing is done via sending requests to your
routes, then analyzing the response.

# WHY KELP?

What makes Kelp different from the other Perl micro web frameworks? There are a
number of fine web frameworks on CPAN, and most of them provide a complete
platform for web app building. While those other frameworks bring their own
deployment code, Kelp is heavily _Plack_\-centric. It uses Plack as its foundation
layer, and it builds the web framework on top of it. `Kelp::Request` is an
extension of `Plack::Request`, `Kelp::Response` is an extension of
`Plack::Response`.
This approach of extending current CPAN code, puts familiar and well tested
tools in the hands of the application developer.

Kelp is a team player and it uses several popular, trusted CPAN modules for its
internals. At the same time it doesn't include modules that it doesn't need,
just because they are considered trendy. It does its best to keep a lean profile
and a small footprint, and it's completely object manager agnostic.

# CREATING A NEW WEB APP

## Directory structure

Before you begin writing the internals of your app, you need to create the
directory structure.

```none
 .
 |--/lib
 |   |--MyApp.pm
 |   |--/MyApp
 |
 |--/conf
 |   |--myapp.conf
 |   |--myapp_test.conf
 |   |--myapp_deployment.conf
 |
 |--/view
 |--/log
 |--/t
 |--app.psgi
```

- __/lib__

    The `lib` folder contains your application modules and any local modules
    that you want your app to use.

- __/conf__

    The `conf` folder is where Kelp will look for configuration files. You need one
    main file, named exactly as your app, with the extension of `.conf`. You can
    also add other files that define different running environments.
    To change the running environment, you can specify the app `mode`, or you can
    set the `KELP_ENV` environment variable.

    ```perl
    my $app = MyApp->new( mode => 'development' );

    ```

    or

    ```none
    % KELP_ENV=development plackup app.psgi

    ```

- __/view__

    This is where the `Template` module will look for template files.

- __/log__

    This is where the `Logger` module will create `error.log`, `debug.log` and
    any other log files that were defined in the configuration.

- __/t__

    The `t` folder is traditionally used to hold test files. It is up to you to use
    it or not, although we strongly recommend that you write some automated test
    units for your web app.

- __app.psgi__

    This is the [PSGI](http://search.cpan.org/perldoc?PSGI) file, of the app, which you will deploy. In it's most basic
    form it should look like this:

    ```perl
    use lib '../lib';
    use MyApp;

    my $app = MyApp->new;
    $app->run;

    ```

## The application modules

Your application's modules should be put in the `lib/` folder. The main module,
in our example `MyApp.pm`, initializes any modules and variables that your
app will use. Here is an example that uses `Moose` to create lazy attributes
and initialize a database connection:

```perl
package MyApp;
use Moose;

has dbh => (
    is      => 'ro',
    isa     => 'DBI',
    lazy    => 1,
    default => sub {
        my $self   = shift;
        my @config = @{ $self->config('dbi') };
        return DBI->connect(@config);
    }
);

sub build {
    my $self = shift;
    $self->route->add("/read/:id", "read");
}

sub read {
    my ( $self, $id ) = @_;
    $self->dbh->selectrow_array(q[
        SELECT * FROM problems
        WHERE id = ?
    ], $id);
}

1;
```

What is happening here?

- First, we create a lazy attribute and instruct it to connect to DBI. Notice that
we have access to the current app and all of its internals via the `$self`
variable. Notice also that the reason we define `dbh` as a _lazy_ attribute
is that `config` will not yet be initialized. All modules are initialized upon
the creation of the object instance, e.g. when we call `MyApp->new`;
- Then, we override Kelp's ["build"](#build) subroutine to create a single route
`/read/:id`, which is assigned to the subroutine `read` in the current module.
- The `read` subroutine, takes `$self` and `$id` (the named placeholder from the
path), and uses `$self->dbh` to retrieve data.

_A note about object managers:_ The above example uses [Moose](http://search.cpan.org/perldoc?Moose). It is entirely
up to you to use Moose, another object manager, or no object manager at all.
The above example will be just as successful if you used our own little
[Kelp::Base](http://search.cpan.org/perldoc?Kelp::Base):

```perl
package MyApp;
use Kelp::Base 'Kelp';

attr dbi => sub {
    ...
};

1;
```

## Routing

Kelp uses a powerful and very flexible router. Traditionally, it is also light
and consists of less than 300 lines of loose code (commends included). You are
encouraged to read [Kelp::Routes](http://search.cpan.org/perldoc?Kelp::Routes), but here are some key points. All examples
are assumed to be inside the ["build"](#build) method and `$r` is equal to
`$self->routes`:

### Destinations

You can direct HTTP paths to subroutines in your modules or, you can use inline
code.

```perl
$r->add( "/home", "home" );  # goes to sub home
$r->add( "/legal", "legal#view" ); # goes to MyApp::Legal::view
$r->add( "/about", sub { "Content for about" }); # inline
```

### Restrict HTTP methods

Make a route only catch a specific HTTP method:

```perl
$r->add( [ POST => '/update' ], "update_user" );
```

### Named captures

Using regular expressions is so Perl. Sometimes, however, it gets a little
overwhelming. Use named paths if you anticipate that you or someone else will
ever want to maintain your code.

#### Explicit

```perl
$r->add( "/update/:id", "update" );

# Later
sub update {
    my ( $self, $id ) = @_;
    # Do something with $id
}
```

#### Optional

```perl
$r->add( "/person/?name", sub {
    my ( $self, $name ) = @_;
    return "I am " . $name // "nobody";
});
```

This will handle `/person`, `/person/` and `/person/jack`.

#### Wildcards

```perl
$r->add( '/*article/:id', 'articles#view' );
```

This will handle `/bar/foo/baz/500` and send it to `MyApp::Articles::view`
with parameters `$article` equal to `bar/foo/baz` and `$id` equal to 500.

### Placeholder restrictions

Paths' named placeholders can be restricted by providing regular expressions.

```perl
$r->add( '/user/:id', {
    check => { id => '\d+' },
    to    => "users#get"
});

# Matches /user/1000, but not /user/abc
```

### Placeholder defaults

This only applies to optional placeholders, or those prefixed with a question mark.
If a default value is provided for any of them, it will be used in case the
placeholder value is missing.

```perl
$r->add( '/:id/?other', defaults => { other => 'info' } );

# GET /100;
# { id => 100, other => 'info' }

# GET /100/delete;
# { id => 100, other => 'delete' }
```

### Bridges

A _bridge_ is a route that has to return a true value in order for the next
route in line to be processed.

```perl
$r->add( '/users', { to => 'Users::auth', bridge => 1 } );
$r->add( '/users/:action' => 'Users::dispatch' );
```

See ["BRIDGES" in Kelp::Routes](http://search.cpan.org/perldoc?Kelp::Routes#BRIDGES) for more information.

### URL building

Each path can be given a name and later a URL can be build using that name and
the necessary arguments.

```perl
$r->add( "/update/:id", { name => 'update', to => 'user#update' } );

# Later

my $url = $self->route->url('update', id => 1000); # /update/1000
```

## Quick development using Kelp::Less

For writing quick experimental web apps and to reduce the boiler plate, one
could use [Kelp::Less](http://search.cpan.org/perldoc?Kelp::Less). In this case all of the code can be put in `app.psgi`:
Look up the POD for `Kelp::Less` for many examples.

## Adding middleware

Kelp, being Plack-centric, will let you easily add middleware. There are two
ways to add middleware:

In `app.psgi`:

```perl
use MyApp;
use Plack::Builder;

my $app = MyApp->new();

builder {
    enable "Plack::Middleware::ContentLength";
    $app->run;
};
```

By overloading the ["run"](#run) subroutine in `lib/MyApp.pm`:

```perl
sub run {
    my $self = shift;
    my $app = $self->SUPER::run(@_);
    Plack::Middleware::ContentLength->wrap($app);
}
```

## Deploying

Deploying a Kelp application is done the same way one would deploy any Plack
app.

```none
% plackup -E deployment -s Starman app.psgi
```

## Testing

Kelp provides a test module called `Kelp::Test`. It is object oriented, and all
methods return the `Kelp::Test` object, so they can be chained together.
Testing is done by sending HTTP requests to an already built application and
analyzing the response. Therefore, each test usually begins with the
["request" in Kelp::Test](http://search.cpan.org/perldoc?Kelp::Test#request) method, which takes a single [HTTP::Request](http://search.cpan.org/perldoc?HTTP::Request) parameter.
It sends the request to the web app and saves the response as an
[HTTP::Response](http://search.cpan.org/perldoc?HTTP::Response) object.

```perl
# file t/test.t

use MyApp;
use Kelp::Test;
use Test::More;
use HTTP::Request::Common;

my $app = MyApp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

$t->request( GET '/path' )
  ->code_is(200)
  ->content_is("It works");

$t->request( POST '/api' )
  ->json_cmp({auth => 1});

done_testing;
```

What is happening here?

- First, we create an instance of the web application module, which we have
previously built and placed in the `lib/` folder. We set the mode of the app to
`test`, so that file `conf/myapp_test.conf` overrides the main configuration.
The test configuration can contain anything you see fit. Perhaps you want to
disable certain modules, or maybe you want to make DBI connect to a different
database.
- Second, we create an instance of the `Kelp::Test` class and tell it that it
will perform all tests using our `$app` instance.
- At this point we are ready to send requests to the app via the
[request](http://search.cpan.org/perldoc?Kelp::Test#request) method. It takes only one argument, an
HTTP::Request object. It is very convenient to use the [HTTP::Request::Common](http://search.cpan.org/perldoc?HTTP::Request::Common)
module here, because you can create common requests using abridged syntax,
i.e. `GET`, `POST`, etc.  The line `$t->request( GET '/path' )` fist
creates a HTTP::Request GET object, and then passes it to the `request` method.
- After we send the request, we can test the response using any of the `Test::`
modules, or via the methods provided by [Kelp::Test](http://search.cpan.org/perldoc?Kelp::Test).
In the above example, we test if we got a code 200 back from `/path` and if the
returned content was `It works`.

Run the rest as usual, using `prove`:

```none
% prove -l t/test.t
```

Take a look at the [Kelp::Test](http://search.cpan.org/perldoc?Kelp::Test) for details and more examples.

## Building an HTTP response

Kelp contains an elegant module, called [Kelp::Response](http://search.cpan.org/perldoc?Kelp::Response), which extends
`Plack::Response` with several useful methods. Most methods return `$self`
after they do the required job.
For the sake of the examples below, let's assume that all of the code is located
inside a route definition.

### Automatic content type

Your routes don't always have to set the `response` object. You could just
return a simple scalar value or a reference to a hash, array or anything that
can be converted to JSON.

```perl
# Content-type automatically set to "text/html"
sub text_route {
    return "There, there ...";
}

# Content-type automatically set to "application/json"
sub json_route {
    return { error => 1,  message => "Fail" };
}
```

### Rendering text

```perl
# Render simple text
$self->res->text->render("It works!");
```

### Rendering HTML

```perl
$self->res->html->render("<h1>It works!</h1>");
```

### Custom content type

```perl
$self->res->set_content_type('image/png');
```

### Return 404 or 500 errors

```perl
sub some_route {
    my $self = shift;
    if ($missing) {
        return $self->res->render_404;
    }
    if ($broken) {
        return $self->res->render_500;
    }
}
```

### Templates

```perl
sub hello {
    my ( $self, $name ) = @_;
    $self->res->template( 'hello.tt', { name => $name } );
}
```

The above example will render the contents of `hello.tt`, and it will set the
content-type to `text/html`. To set a different content-type, use
`set_content_type` or any of its aliases:

```perl
sub hello_txt {
    my ( $self, $name ) = @_;
    $self->res->text->template( 'hello_txt.tt', { name => $name } );
}
```

### Headers

```perl
$self->set_header( "X-Framework", "Kelp" )->render( { success => \1 } );
```

### Delayed responses

To send a delayed response, have your route return a subroutine.

```perl
sub delayed {
    my $self = shift;
    return sub {
        my $responder = shift;
        $self->res->code(200);
        $self->res->text->body("Better late than never.");
        $responder->($self->res->finalize);
    };
}
```

See the [PSGI](http://search.cpan.org/perldoc?PSGI#Delayed-Response-and-Streaming-Body) pod for more
information and examples.

# ATTRIBUTES

## host

Gets the current hostname.

```perl
sub some_route {
    my $self = shift;
    if ( $self->hostname eq 'prod-host' ) {
        ...
    }
}
```

## mode

Sets or gets the current mode. The mode is important for the app to know what
configuration file to merge into the main configuration. See
[Kelp::Module::Config](http://search.cpan.org/perldoc?Kelp::Module::Config) for more information.

```perl
my $app = MyApp->new( mode => 'development' );
# conf/myapp.conf and conf/myapp_development.conf are merged with priority
# given to the second one.
```

## path

Gets the current path of the application. That would be the path to `app.psgi`

## name

Gets or sets the name of the application. If not set, the name of the main
module will be used.

```perl
my $app = MyApp->new( name => 'Twittar' );
```

The `name` is used to look for configuration files. In the above example, the
app will look for `conf/twittar.conf` and `conf/twittar_*.conf` files.

## charset

Sets of gets the encoding charset of the app. It will be `UTF-8`, if not set to
anything else. The charset could also be changed in the config files.

## req

This attribute only makes sense if called within a route definition. It will
contain a reference to the current [Kelp::Request](http://search.cpan.org/perldoc?Kelp::Request) instance.

```perl
sub some_route {
    my $self = shift;
    if ( $self->req->is_json ) {
        ...
    }
}
```

## res

This attribute only makes sense if called within a route definition. It will
contain a reference to the current [Kelp::Response](http://search.cpan.org/perldoc?Kelp::Response) instance.

```perl
sub some_route {
    my $self = shift;
    $self->res->json->render( { success => 1 } );
}
```

# METHODS

## build

On it's own the `build` method doesn't do anything. It is called by the
constructor, so it can be overridden to add route destinations and
initializations.

```perl
package MyApp;

sub build {
    my $self = shift;
    my $r = $self->routes;

    # Load some modules
    $self->load_module("MongoDB");
    $self->load_module("Validate");

    # Add all route destinations
    $r->add("/one", "one");
    ...

}
```

## load\_module

Used to load a module. All modules must be under the `Kelp::Module::`
namespace.

```perl
$self->load_module("Redis");
# Will look for an load Kelp::Module::Redis
```

See [Kelp::Module](http://search.cpan.org/perldoc?Kelp::Module) for more information on making and using modules.

## request

This method is used to create the request object for each HTTP request. It
returns and instance of [Kelp::Request](http://search.cpan.org/perldoc?Kelp::Request), initialized with the current requests
environment. You can override this method to use a custom request module.

```perl
package MyApp;
use MyApp::Request;

sub request {
    my ( $self, $env ) = @_;
    return MyApp::Requst->new( app => $app, env => $env );
}

# Now each request will be handled by MyApp::Request
```

## before\_render

Override this method, to modify the response object just before it gets
rendered.

```perl
package MyApp;

sub before_render {
    my $self = shift;
    $self->res->set_header("X-App-Name", "MyApp");
}

...
```

The above is an example of how to insert a custom header into the response of
every route.

## response

This method creates the response object, e.g. what an HTTP request will return.
By default the object created is [Kelp::Response](http://search.cpan.org/perldoc?Kelp::Response). Much like ["request"](#request), the
response can also be overridden to use a custom response object.

## run

This method builds and returns the PSGI app. You can override it in order to
include middleware. See ["Adding middleware"](#Adding middleware) for an example.

## param

A shortcut to `$self->req->param`:

```perl
sub some_route {
    my $self = shift;
    if ( $self->param('age') > 18 ) {
        $self->can_watch_south_path(1);
    }
}
```

See [Kelp::Request](http://search.cpan.org/perldoc?Kelp::Request) for more information and examples.

## stash

Provides safe access to `$self->req->stash`. When called without
arguments, it will return the stash hash. If called with a single argument, it
will return the value of the corresponding key in the stash.
See ["stash" in Kelp::Request](http://search.cpan.org/perldoc?Kelp::Request#stash) for more information and examples.

## named

Provides safe access to `$self->req->named`. When called without
arguments, it will return the named hash. If called with a single argument, it
will return the value of the corresponding key in the named hash.
See ["named" in Kelp::Request](http://search.cpan.org/perldoc?Kelp::Request#named) for more information and examples.

## url\_for

A safe shortcut to `$self->routes->url`. Builds a URL from path and
arguments.

```perl
sub build {
    my $self = shift;
    $self->routes->add("/:name/:id", { name => 'name', to => sub {
        ...
    }});
}

sub check {
    my $self = shift;
    my $url_for_name = $self->url_for('name', name => 'jake', id => 1003);
    $self->res->redirect_to();
}
```

# SEE ALSO

[Kelp](http://search.cpan.org/perldoc?Kelp)

# CREDITS

Author: Stefan Geneshky - minimal@cpan.org

# LICENSE

Same as Perl itself.
