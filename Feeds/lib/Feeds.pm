package Feeds;
use Dancer2;

our $VERSION = '0.1';

use LWP::Simple();
use Path::Tiny;
use Encode 'encode';

my %feeds = (
  perl => {
    feed => 'rss',
    type => 'uri',
    uri  => 'https://perlhacks.com/feed/',
  },
  blog => {
    feed => 'rss',
    type => 'uri',
    uri  => 'https://blog.dave.org.uk/feed/',
  }
  music => {
    feed => 'atom',
    type => 'file',
    path => '/var/www/vhosts/dave.org.uk/httpdocs/feed-data/lastfm.xml',
  },
  video => {
    feed => 'atom',
    type => 'uri',
    uri  => 'https://trakt.tv/users/davorg/history.atom?slurm=e94f879ae8bd21e4c6aca5a25228eeda',
  },
);

get '/' => sub {
  template 'index' => {
    title => 'Feeds',
    feeds => \%feeds,
  };
};

get '/:feed' => sub {
  my $feed = route_parameters->get('feed');

  if (exists $feeds{$feed}) {
    $feed = $feeds{$feed};
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
    return encode 'UTF-8', LWP::Simple::get $feed->{uri};
  }

  return $feed;
};

true;
