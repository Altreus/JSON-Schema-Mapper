#!perl
use strict;
use warnings;

use Dir::Self;
use lib __DIR__ . '/lib';
use Test::Most;
use List::Util 'sum';
use JSON::MaybeXS;

use Test::Schema::Artist;
use Test::Schema::Album;
use Test::Structs;

sub t {
    my $i = 0;
    return sum map { $_ * (60 ** $i++) } reverse split /:/, $_[0];
}

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
    ],
    artist => undef,
);

my $artist = Artist(
    name => 'U2',
    wikipedia_url => 'https://en.wikipedia.org/wiki/U2',
    albums => [ $tuf ],
);

$tuf->artist = $artist;

subtest artist => sub {
    my $mapper = Test::Schema::Artist->new;
    is_deeply(
        decode_json( $mapper->to_json($artist) ),
        {
            albums => [
                {
                    name => "The Unforgettable Fire",
                    runtime => "0:42:37",
                    trackCount => 10,
                    year => 1984
                }
            ],
            name => "U2",
            wikipedia => "https://en.wikipedia.org/wiki/U2"
        }
    );
};

subtest album => sub {
    my $mapper = Test::Schema::Album->new;
    is_deeply(
        decode_json( $mapper->to_json($tuf) ),
        {
            name => "The Unforgettable Fire",
            year => 1984,
            artist => {
                name => "U2",
                wikipedia => "https://en.wikipedia.org/wiki/U2"
            },
            tracks => [
                {
                    title => "A Sort Of Homecoming",
                    duration =>  "5:28",
                },
                {
                    title => "Pride (In The Name Of Love)",
                    duration =>  "3:48",
                },
                {
                    title => "Wire",
                    duration =>  "4:19",
                },
                {
                    title => "The Unforgettable Fire",
                    duration =>  "4:55",
                },
                {
                    title => "Promenade",
                    duration =>  "2:35",
                },
                {
                    title => "4th Of July",
                    duration =>  "2:12",
                },
                {
                    title => "Bad",
                    duration =>  "6:09",
                },
                {
                    title => "Indian Summer Sky",
                    duration =>  "4:17",
                },
                {
                    title => "Elvis Presley And America",
                    duration =>  "6:23",
                },
                {
                    title => "MLK",
                    duration =>  "2:31",
                },
            ]
        }
    );
};

done_testing;
