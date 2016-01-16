package Test::Schema::Album;

use Moose;
with 'JSON::Schema::Mapper';

use List::Util 'sum';

sub _json_schema {
    +{
        title => 'Album',
        properties => {
            name => 'string',
            artist => {
                properties => {
                    name => 'string',
                    wikipedia => {
                        type => 'string',
                        format => 'uri',
                    },
                }
            },
            name => 'string',
            year => 'number',
        }
    }
}

sub _map {
    +{
        title => 'name',
        artist => {
            artist => {
                name => 'name',
                wikipedia_url => 'wikipedia',
            },
        },
        tracks => {
            tracks => [{
                title => 'title',
                duration => sub {
                    my ($obj, $field) = @_;
                    my $runtime = $obj->$field;
                    my $s = $runtime % 60;
                    $runtime -= $s;
                    $runtime /= 60;

                    my $m = $runtime % 60;
                    $runtime -= $m;
                    $runtime /= 60;

                    # Probably never going to use hours in this test.
                    return ($field, sprintf '%d:%02d', $m, $s);
                }
            }],
        },
        year => 'year'
    }
}
