use Kelp::Base -strict;

use Kelp;
use Kelp::Test;
use HTTP::Request::Common;
use Test::More;

my $app = Kelp->new( mode => 'test' );
my $t = Kelp::Test->new( app => $app );

# is_json
$app->add_route('/json', sub {
    return $_[0]->req->is_json ? "ok" : "fail";
});
$t->request( GET '/json', Content_Type => 'application/json' )
  ->code_is(200)
  ->content_is('ok');

# is_ajax
$app->add_route('/ajax', sub {
    return $_[0]->req->is_ajax ? "ok" : "fail";
});
$t->request( GET '/ajax', 'X-Requested-With' => 'XMLHttpRequest' )
  ->code_is(200)
  ->content_is('ok');

# param
$app->add_route('/param/:n', sub {
    my ( $self, $n ) = @_;
    if ($n == 1) {
        [ $self->param ];
    }
    elsif ($n == 2) {
        my %h = map { $_ => $self->param($_) } $self->param;
        return \%h;
    }
});
$t->request( POST '/param/1',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
  ->code_is(200)
  ->json_cmp(['a', 'b'], "Get JSON list of params");

$t->request( POST '/param/2',
    'Content-Type' => 'application/json',
    'Content' => '{"a":"bar","b":"foo"}'
    )
  ->code_is(200)
  ->json_cmp({a => "bar", b => "foo"}, "Get JSON struct of params");

$t->request( POST '/param/1', [a => "bar", b => "foo"])
  ->code_is(200)
  ->json_cmp(['a', 'b'], "Get POST list of params");

$t->request( POST '/param/2', [a => "bar", b => "foo"])
  ->code_is(200)
  ->json_cmp({a => "bar", b => "foo"}, "Get POST struct of params");

done_testing;
