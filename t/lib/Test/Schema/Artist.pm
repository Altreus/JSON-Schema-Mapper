package Test::Schema::Artist;

use Moose;
with 'JSON::Schema::Mapper';

use List::Util 'sum';

sub _json_schema {
    +{
        title => 'Artist',
        properties => {
            name => 'string',
            albums => {
                type => 'array',
                items => {
                    properties => {
                        name => 'string',
                        trackCount => 'number',
                        runtime => {
                            '$ref' => '#/definitions/time'
                        },
                        year => 'number',
                    }
                }
            },
            wikipedia => {
                type => 'string',
                format => 'uri',
            },
        },
        definitions => {
            time => {
                type => 'string',
                pattern => '^[0-9]?[0-9]:[0-6][0-9]:[0-6][0-9]$',
            }
        }
    }
}

sub _map {
    +{
        name => 'name',
        albums => {
            albums => [ {
                title => 'name',
                tracks => sub {
                    my ($obj, $field) = @_;
                    return ('trackCount', scalar @{ $obj->tracks || [] });
                },
                runtime => sub {
                    my ($obj, $field) = @_;
                    my $runtime = sum map $_->duration, @{ $obj->tracks || [] };
                    my $s = $runtime % 60;
                    $runtime -= $s;
                    $runtime /= 60;

                    my $m = $runtime % 60;
                    $runtime -= $m;
                    $runtime /= 60;

                    my $h = $runtime / 60;

                    return ($field, "$h:$m:$s");
                },
                year => 'year',
            } ],
        },
        wikipedia_url => 'wikipedia'
    }
}
