use strict;
use warnings;

use Feeds;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use HTTP::Response;

my $requested_uri;
my $fetches = 0;

{
  no warnings 'redefine';
  local *Feeds::get_proxy_uri = sub {
    ($requested_uri) = @_;
    ++$fetches;

    my $res = HTTP::Response->new(202, 'Accepted');
    $res->header('Content-Type' => 'application/json; charset=UTF-8');
    $res->header('Cache-Control' => 'max-age=60');
    $res->content('{"ok":true}');

    return $res;
  };

  my $app = Feeds->to_app;
  my $test = Plack::Test->create($app);

  my $res = $test->request(
    GET '/url/https%3A%2F%2Fexample.com%2Fdata.json%3Fx%3D1'
  );

  is $res->code, 202, 'returns upstream status';
  is $res->decoded_content, '{"ok":true}', 'returns upstream body';
  like $res->header('Content-Type'), qr{\Aapplication/json; charset=UTF-8},
    'returns upstream content type';
  is $res->header('Access-Control-Allow-Origin'), '*', 'adds CORS header';
  is $res->header('Cache-Control'), 'max-age=60', 'copies safe cache header';
  is "$requested_uri", 'https://example.com/data.json?x=1', 'decodes target URL';
  is $fetches, 1, 'fetches upstream once';

  $res = $test->request(GET '/url/file%3A%2F%2F%2Fetc%2Fpasswd');
  is $res->code, 400, 'rejects non-HTTP scheme';
  is $res->header('Access-Control-Allow-Origin'), '*',
    'adds CORS header to validation errors';
  is $fetches, 1, 'does not fetch invalid scheme';

  $res = $test->request(GET '/url/http%3A%2F%2F127.0.0.1%2Fsecret');
  is $res->code, 403, 'rejects loopback IP target';
  is $fetches, 1, 'does not fetch blocked host';
}

done_testing;
