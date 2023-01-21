package Feeds;
use Dancer2;

our $VERSION = '0.1';

use LWP::UserAgent;
use Path::Tiny;
use Encode 'encode';
use JSON ();

hook before => sub {
  my $json_p = JSON->new;
  warn request->base, "\n";
  my $json = get_uri(request->base . 'feeds.json');

  warn "Feeds JSON: $json\n";

  var feeds => $json_p->decode($json);
};

get '/' => sub {
  template 'index' => {
    title => 'Feeds',
    feeds => vars->{feeds},
  };
};

get '/:feed' => sub {
  my $feed = route_parameters->get('feed');

  if (exists vars->{feeds}{$feed}) {
    $feed = vars->{feeds}{$feed};
  } else {
    status(404);
    return "$feed is not a known feed";
  }

  content_type "application/$feed->{feed}+xml";
  response_header 'Access-Control-Allow-Origin' => '*';

  if ($feed->{type} eq 'file') {
    my $data = path($feed->{path})->slurp_utf8;
    return encode 'UTF-8', $data;
  }

  if ($feed->{type} eq 'uri') {
    return encode 'UTF-8', get_uri($feed->{uri});
  }

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

  return $resp->content;
}
