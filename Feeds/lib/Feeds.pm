package Feeds;
use Dancer2;

use HTTP::Exception;

use feature 'say';

our $VERSION = '0.1';

use LWP::UserAgent;
use Path::Tiny;
use Encode qw[decode encode];
use JSON ();
use Sys::Hostname;

my $feed_type = {
  file => sub {
    my $feed = shift;

    content_type "application/$feed->{feed}+xml; charset=UTF-8";

    return path($feed->{path})->slurp_utf8;
  },
  uri => sub {
    my $feed = shift;

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
    host  => hostname,
  };
};

get '/:feed' => sub {
  my $feed_name = route_parameters->get('feed');
  my $feed;

  if (exists config->{feeds}{$feed_name}) {
    $feed = config->{feeds}{$feed_name};
  } else {
    HTTP::Exception(404, "$feed_name is not a known feed");
    return;
  }

  response_header 'Access-Control-Allow-Origin' => '*';

  if (exists $feed_type->{$feed->{type}}) {
    return $feed_type->{$feed->{type}}->($feed);
  } else {
    HTTP::Exception->throw(404, "Unknown feed type: $feed->{type}");
  }
};

true;

sub get_uri {
  my ($uri) = shift;

  # TODO: Persist the UA under PSGI?
  my $ua = LWP::UserAgent->new( agent => "Dave's Feed Engine" );
  my $resp = $ua->get($uri);

  if (! $resp->is_success) {
    HTTP::Exception->throw($resp->code, $resp->status_line);
    return;
  }

  my $content = $resp->decoded_content;
  my $charset = $resp->content_charset;

  return ($content, $charset);
}

1;
