package Feeds;
use Dancer2;

use HTTP::Exception;

use feature 'say';

our $VERSION = '0.1';

use LWP::UserAgent;
use Path::Tiny;
use Encode qw[decode encode];
use JSON ();

use Feeds::Feed;

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

my $formats = { map { $_ => 1 } qw[yaml json] };

get '/' => sub {
  template 'index' => {
    title => 'Feeds',
    feeds => config->{feeds},
  };
};

get '/:feed' => sub {
  my $feed_name = route_parameters->get('feed');
  my $feed_config;

  if (exists config->{feeds}{$feed_name}) {
    $feed_config = config->{feeds}{$feed_name};
  } else {
    HTTP::Exception(404, "$feed_name is not a known feed");
    return;
  }

  response_header 'Access-Control-Allow-Origin' => '*';

  my $format = query_parameters->get('format') // '';

  if ($format && ! exists $formats->{$format}) {
    HTTP::Exception->throw(400, "Unknown format: $format");
  }  

  my $feed = Feeds::Feed->new(%$feed_config);

  if ($format eq 'json') {
    content_type 'application/json';
use Data::Printer;
p $feed->data;
    return encode_json($feed->data);
  } elsif ($format eq 'yaml') {
    content_type 'application/yaml';
    return to_yaml($feed->data);
  } else {
    content_type "application/xml";
    return $feed->text;
  }
};

true;


1;