package Feeds;
use Dancer2;

use feature 'say';

our $VERSION = '0.1';

use LWP::UserAgent;
use Path::Tiny;
use Encode qw[decode encode];
use JSON ();

my $feed_type = {
  file => sub {
    my $feed = shift;

    content_type "application/$feed->{feed}+xml; charset=UTF-8";

    return path($feed->{path})->slurp_utf8;
  },
  uri => sub {
    my $feed = shift;

    # TODO: Is there any point in decoding the data in the sub
    # only to encode it again here?
    my ($data, $charset) = get_uri($feed->{uri});
    my $content_type = "application/$feed->{feed}+xml";
    $content_type .= "; charset=$charset" if $charset;
    content_type $content_type;

    return encode 'UTF-8', $data;
  },
};

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

  response_header 'Access-Control-Allow-Origin' => '*';

  if (exists $feed_type->{$feed->{type}}) {
    return $feed_type->{$feed->{type}}->($feed);
  } else {
    # TODO: Use HTTP::Exception?
    die "Unknown feed type: $feed->{type}";
  }
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

  my $content = $resp->decoded_content;
  my $charset = $resp->content_charset;

  return ($content, $charset);
}

1;