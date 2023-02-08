package Feeds;
use Dancer2;

use feature 'say';

our $VERSION = '0.1';

use LWP::UserAgent;
use Path::Tiny;
use Encode qw[decode encode];
use JSON ();

get '/' => sub {
  template 'index' => {
    title => 'Feeds',
    feeds => config->{feeds},
  };
};

get '/:feed' => sub {
  my $feed = route_parameters->get('feed');

  if (exists config->{feeds}{$feed}) {
    $feed = config->{feeds}{$feed};
  } else {
    status(404);
    return "$feed is not a known feed";
  }

  content_type "application/$feed->{feed}+xml; charset=UTF-8";
  response_header 'Access-Control-Allow-Origin' => '*';

  if ($feed->{type} eq 'file') {
    my $data = decode path($feed->{path})->slurp_utf8;
    return encode 'UTF-8', $data;
  }

  if ($feed->{type} eq 'uri') {
    return encode 'UTF-8', get_uri($feed->{uri});
  }

  warn "Unknown feed type: $feed->{type}";

  return $feed;
};

true;

sub get_uri {
  my ($uri) = shift;

  my $ua = LWP::UserAgent->new( agent => "Dave's Feed Engine" );
  my $resp = $ua->get($uri);

  if (! $resp->is_success) {
    die $resp->status_line;
    return;
  }

  return decode $resp->content;
}
