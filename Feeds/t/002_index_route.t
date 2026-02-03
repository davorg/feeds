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
  or diag $res->message;

my $feed_type = Feeds->config->{feeds}{$feed_key}{feed};

like( $res->header('Content-type'), qr[^application/$feed_type\+xml],
    'Correct content type');

# Test that all feeds have descriptions
foreach my $feed_name (keys %{Feeds->config->{feeds}}) {
  ok( exists Feeds->config->{feeds}{$feed_name}{description},
      "Feed '$feed_name' has a description field" );
  ok( defined Feeds->config->{feeds}{$feed_name}{description},
      "Feed '$feed_name' description is defined" );
  ok( length(Feeds->config->{feeds}{$feed_name}{description}) > 0,
      "Feed '$feed_name' description is not empty" );
}

# Test that the index page contains descriptions
$res = $test->request( GET '/' );
my $content = $res->decoded_content;
foreach my $feed_name (keys %{Feeds->config->{feeds}}) {
  my $desc = Feeds->config->{feeds}{$feed_name}{description};
  like( $content, qr/\Q$desc\E/,
      "Index page contains description for '$feed_name'" );
}

done_testing;
