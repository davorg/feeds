#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use Feeds;

Feeds->to_app;

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use Feeds;
use Plack::Builder;

builder {
    enable 'Deflater';
    Feeds->to_app;
}

=end comment

=cut

=begin comment
# use this block if you want to mount several applications on different path

use Feeds;
use Feeds_admin;

use Plack::Builder;

builder {
    mount '/'      => Feeds->to_app;
    mount '/admin'      => Feeds_admin->to_app;
}

=end comment

=cut

