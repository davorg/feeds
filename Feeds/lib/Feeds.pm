package Feeds;
use Dancer2;

use HTTP::Exception;

use feature 'say';

our $VERSION = '0.1';

use LWP::UserAgent;
use Path::Tiny;
use Encode qw[decode encode];
use JSON ();
use Socket qw(AF_INET AF_INET6 inet_pton);
use Sys::Hostname;
use URI;
use URI::Escape qw(uri_unescape);

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

get qr{^/url/(.+)$} => sub {
  my ($encoded_url) = splat;
  my $url = uri_unescape($encoded_url);

  response_header 'Access-Control-Allow-Origin' => '*';

  my ($uri, $error) = validate_proxy_uri($url);
  if ($error) {
    status $error->{status};
    content_type 'text/plain; charset=UTF-8';
    return $error->{message};
  }

  my $resp = get_proxy_uri($uri);

  status $resp->code;
  content_type $resp->header('Content-Type') || 'application/octet-stream';

  for my $header (qw(Cache-Control ETag Expires Last-Modified)) {
    my $value = $resp->header($header);
    response_header $header => $value if defined $value;
  }

  return $resp->content;
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

sub get_proxy_uri {
  my ($uri) = @_;

  my $ua = LWP::UserAgent->new(
    agent             => "Dave's Feed Engine",
    max_size              => 5 * 1024 * 1024,
    max_redirect          => 0,
    timeout               => 10,
    protocols_allowed     => [qw(http https)],
    requests_redirectable => [],
  );

  return $ua->get($uri);
}

sub validate_proxy_uri {
  my ($url) = @_;
  my $uri = URI->new($url);

  if (! $uri->scheme || $uri->scheme !~ /\Ahttps?\z/i) {
    return proxy_validation_error(400, 'Proxy URL must use http or https');
  }

  my $host = $uri->host;
  if (! defined $host || ! length $host) {
    return proxy_validation_error(400, 'Proxy URL must include a host');
  }

  if (is_blocked_proxy_host($host)) {
    return proxy_validation_error(403, 'Proxy URL host is not allowed');
  }

  return ($uri, undef);
}

sub proxy_validation_error {
  my ($status, $message) = @_;

  return (undef, { status => $status, message => $message });
}

sub is_blocked_proxy_host {
  my ($host) = @_;

  $host =~ s/\A\[(.*)\]\z/$1/;
  return 1 if $host =~ /\Alocalhost\.?\z/i;
  return 1 if $host =~ /\.localhost\.?\z/i;

  my $ipv4 = inet_pton(AF_INET, $host);
  return is_blocked_ipv4($ipv4) if defined $ipv4;

  my $ipv6 = inet_pton(AF_INET6, $host);
  return is_blocked_ipv6($ipv6) if defined $ipv6;

  return 0;
}

sub is_blocked_ipv4 {
  my ($packed) = @_;
  my $ip = unpack 'N', $packed;

  return 1 if ($ip & 0xff000000) == 0x00000000; # 0.0.0.0/8
  return 1 if ($ip & 0xff000000) == 0x0a000000; # 10.0.0.0/8
  return 1 if ($ip & 0xffc00000) == 0x64400000; # 100.64.0.0/10
  return 1 if ($ip & 0xff000000) == 0x7f000000; # 127.0.0.0/8
  return 1 if ($ip & 0xffff0000) == 0xa9fe0000; # 169.254.0.0/16
  return 1 if ($ip & 0xfff00000) == 0xac100000; # 172.16.0.0/12
  return 1 if ($ip & 0xffff0000) == 0xc0a80000; # 192.168.0.0/16
  return 1 if ($ip & 0xfffe0000) == 0xc6120000; # 198.18.0.0/15
  return 1 if ($ip & 0xf0000000) == 0xe0000000; # 224.0.0.0/4

  return 0;
}

sub is_blocked_ipv6 {
  my ($packed) = @_;
  my @bytes = unpack 'C16', $packed;

  return 1 if $packed eq ("\0" x 16); # ::
  return 1 if $packed eq ("\0" x 15) . "\1"; # ::1
  return 1 if ($bytes[0] & 0xfe) == 0xfc; # fc00::/7
  return 1 if $bytes[0] == 0xfe && ($bytes[1] & 0xc0) == 0x80; # fe80::/10

  return 0;
}


1;
