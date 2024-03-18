use Feature::Compat::Class;

class Feeds::Feed {
  use LWP::UserAgent;
  use HTTP::Exception;
  use Path::Tiny;
  use XML::Feed;

  field $text;
  field $charset;
  field $xml_feed;
  field $type :param;
  field $feed :param;
  field $uri :param = '';
  field $path :param = '';

  method text {
    if (!$text) {
      if ($type eq 'file') {
        $text = path($path)->slurp_utf8;
        $charset = 'utf-8';
      } elsif ($type eq 'uri') {
        $self->get_uri;
      } else {
        die "Unknown feed type: $type";
      }
    }

    return $text
  }

  method charset { return $charset }
  method type { return $type }
  method url { return $url }
  method path { return $path }

  method get_uri {
    # TODO: Persist the UA under PSGI?
    my $ua = LWP::UserAgent->new( agent => "Dave's Feed Engine" );
    my $resp = $ua->get($uri);

    if (! $resp->is_success) {
      HTTP::Exception->throw($resp->code, $resp->status_line);
      return;
    }

    $text = $resp->decoded_content;
    $charset = $resp->content_charset;
  }

  method xml_feed {
    my $text = $self->text;
    if (!$xml_feed) {
      $xml_feed = XML::Feed->parse(\$text);
    }

    return $xml_feed;
  }

  method data {
    my $xml_feed = $self->xml_feed;
    my $data = {
      title => $xml_feed->title,
      link => $xml_feed->link,
      description => $xml_feed->description,
      items => [],
    };

    for my $entry ($xml_feed->entries) {
      push @{$data->{items}}, {
        title => $entry->title,
        link => $entry->link,
        description => $entry->summary->body,
        date => $entry->issued->iso8601,
      };
    }

    return $data;
  }
}

1;