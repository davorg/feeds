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
  my $feed_name = route_parameters->get('feed');
  my $feed;

  if (exists config->{feeds}{$feed_name}) {
    $feed = config->{feeds}{$feed_name};
  } else {
    status(404);
    return "$feed_name is not a known feed";
  }

  # TODO: Only set the content type once we know it's
  # a valid feed and (more importantly) what the charset is
  content_type "application/$feed->{feed}+xml; charset=UTF-8";
  response_header 'Access-Control-Allow-Origin' => '*';

  # TODO: Dispatch table
  if ($feed->{type} eq 'file') {
    # TODO: This decode/encode seems pointless
    my $data = decode 'UTF-8', path($feed->{path})->slurp_utf8;
    return encode 'UTF-8', $data;
  }

  if ($feed->{type} eq 'uri') {
    # TODO: Is there any point in decoding the data in the sub
    # only to encode it again here?
    return encode 'UTF-8', get_uri($feed->{uri});
  }

  # TODO: Should this die, not warn?
  warn "Unknown feed type: $feed->{type}";

  # TODO: What should we really return here?
  # TODO: Use HTTP::Exception?
  return $feed;
};

true;

sub get_uri {
  my ($uri) = shift;

  # TODO: Persist the UA under PSGI?
  my $ua = LWP::UserAgent->new( agent => "Dave's Feed Engine" );
  my $resp = $ua->get($uri);

  # TODO: Throw an HTTP::Exception here?
  if (! $resp->is_success) {
    die $resp->status_line;
    return;
  }

  # TODO: This is pointless if we just encode the data again
  return decode 'UTF-8', $resp->content;
}
