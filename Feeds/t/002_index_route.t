use strict;
use warnings;

use Feeds;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

my $app = Feeds->to_app;
ok( is_coderef($app), 'Got app' );

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_success, '[GET /] successful' )
  or diag $res->message;;

like( $res->header('Content-type'), qr[^text/html],
    'Correct content type');

my $feed_key = (keys %{Feeds->config->{feeds}})[0];
diag "Testing feed - $feed_key";

$res = $test->request( GET "/$feed_key" );

ok( $res->is_success, "[GET /$feed_key] successful" )
  or diag $res->message;;

my $feed_type = Feeds->config->{feeds}{$feed_key}{feed};

like( $res->header('Content-type'), qr[^application/$feed_type+xml],
    'Correct content type');

done_testing;
