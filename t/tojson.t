#!perl
use strict;
use warnings;

use Dir::Self;
use lib __DIR__ . '/lib';
use Test::Most;
use Test::Schema::Artist;
use Test::Structs;
use List::Util 'sum';

sub t {
    my $i = 0;
    return sum map { $_ * (60 ** $i++) } reverse split /:/, $_[0];
}
my $mapper = Test::Schema::Artist->new;
my $tuf = Album(
    title => "The Unforgettable Fire",
    year => 1984,
    tracks => [
        Track("A Sort Of Homecoming", t "5:28"),
        Track("Pride (In The Name Of Love)", t "3:48"),
        Track("Wire", t "4:19"),
        Track("The Unforgettable Fire", t "4:55"),
        Track("Promenade", t "2:35"),
        Track("4th Of July", t "2:12"),
        Track("Bad", t "6:09"),
        Track("Indian Summer Sky", t "4:17"),
        Track("Elvis Presley And America", t "6:23"),
        Track("MLK", t "2:31"),
    ]
);

my $artist = Artist(
    name => 'U2',
    wikipedia_url => 'https://en.wikipedia.org/wiki/U2',
    albums => [ $tuf ],
);

print $mapper->to_json($artist);
