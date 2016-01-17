package JSON::Schema::Mapper;

use Moose::Role;
use JSON::MaybeXS ();
use Scalar::IfDefined qw($ifdef);

our $VERSION = '0.001';

=head1 NAME

JSON::Schema::Mapper - Assists in converting data objects to JSON via JSON schemata

=head1 DESCRIPTION

This role allows an object to define a relationship between a data object and a
JSON-Schema object, by means of a mapping definition. The mapping definition
will normally match the structure of the JSON-Schema hashref, by using attribute
or relation names as keys, and the equivalent JSON-schema keys as values.

The easiest way to use it is just to consume it and provide the builder methods
for the properties.

Nominally the data object will be a L<DBIx::Class::Row> object, but in fact you
can use any object whose accessors match the columns you define in the mapping.

No attempt is made to use the JSON Schema to validate anything; nor is any
attempt made to resolve links found inside the schema itself. This may be
implemented in future, if anyone can figure out how to get C<JSON::Hyper> to
work with C<JSON::Schema>.

B<It is assumed> that your JSON Schema defines an B<object> type. This is
because, for various reasons, it is recommended that the response to a JSON
request is a JSON object (rather than a string, int, boolean or array). If you
need to return a simple item, the common practice is to put it in an object with
a consistent key:

    {
        theBooleanIs: false
    }

=head1 PROPERTIES

=head2 json_schema

Defines a hashref that will be serialised as JSON to produce a document of type
C<application/schema+json>.

    sub _json_schema {
        +{
            ...
        }
    }

=cut

has json_schema => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_json_schema'
);

=head2 map

Defines a hashref that describes the fields on the DBIC Result class as keys and
the fields in the JSON schema as values.

The mapping can be complex. L<Examples below|/MAPPING>.

    sub _map {
        +{
            ...
        }
    }

=cut

has map => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_map'
);

=head1 METHODS

=head2 to_json

Given an object, transforms it based on C<map> and returns the resultant
hashref. If your map is right, the hashref will conform to C<json_schema>.

Assumes all things in the C<map> are callable as methods on the object.

=cut

sub to_json {
    my ($self, $obj) = @_;
    die "No object to encode" unless defined $obj;

    JSON::MaybeXS
        ->new(utf8 => 1, pretty => 1, canonical => 1)
        ->encode($self->_map_href($obj, $self->map));
}

# Uses $map (a hashref) to turn $obj into a hashref. $map will originally come
# from $self->map but may be a nested hashref further down.
sub _map_href {
    my ($self, $obj, $map) = @_;
    +{
        map { $self->_map_value($obj, $_, $map->{$_}) }
        keys %$map
    };
}

# given $object and ( $object_field => $spec ), return ( $json_field => $value )
sub _map_value {
    my ($self, $obj, $field, $spec) = @_;
    my ($json_field, $value);

    if (not ref $spec) {
        return ($spec => scalar $obj->$ifdef($field));
    }

    if (ref $spec eq 'HASH') {
        # single nested object: $field => { $json_field => $inner_spec }
        ($json_field) = keys %$spec;
        my $inner_spec = $spec->{$json_field};

        if (ref $inner_spec eq 'HASH') {
            # when $inner_spec is a hashref, it's one related object.
            $value = $self->_map_href(scalar $obj->$ifdef($field), $inner_spec);
        }
        elsif (ref $inner_spec eq 'ARRAY') {
            # when $inner_spec is an arrayref, it's many related objects.
            ($inner_spec) = @$inner_spec;

            # If it returns a single unblessed arrayref it needs to be deref'd.
            # We can only work on blessed related things. Observe that
            # $inner_spec must be a hashref, so it must be a map itself.
            my @inner = $obj->$ifdef($field);
            if (ref $inner[0] and ref $inner[0] eq 'ARRAY') {
                @inner = @{ $inner[0] };
            }

            $value = [ map $self->_map_href($_, $inner_spec), @inner ];
        }
        return ($json_field => $value);
    }

    if (ref $spec eq 'CODE') {
        return $spec->($obj, $field);
    }

}

1;

=head1 MAPPING

A simple mapping just relates object fields to JSON fields.

    {
        id => 'id',
        album_id => 'albumId',
        ...
    }

The keys will be called as methods on the object, so they can actually be any
accessor you like.

    {
        generate_hash => 'hash'
    }

This means you can provide as keys method names that will return complex
structures - for example, you might provide a relation name on a DBIC row. But
if you do that, you don't get an atomic value back, so how do you deal with the
value?

You nest the hashrefs.

    {
        dbic_relation => {
            jsonEquivalent => {
                id => 'id',
                column_name => 'fieldName'
            }
        }
    }

The C<dbic_relation> key to the hashref causes the C<dbic_relation> method to be
run. In this case, it is expected that C<dbic_relation> returns a single item;
the JSON for this item will go under the C<jsonEquivalent> key in the output.
Then there is a second level of nesting, which defines how C<<
$obj->dbic_relation >> (remember - this returns one thing) is converted to the
JSON object that goes under C<jsonEquivalent>.

In this format, the hashref should therefore only have a single key; it is this
key name that determines the new name for the related object.

Here's a more thorough example. First, the JSON-Schema document; then the
mapping that pulls the album information out of the Track object.

    # Schema
    {
        title => 'Track',
        properties => {
            id => { type => 'number' },
            album => {
                type => 'object',
                properties => {
                    id => { type => 'number' },
                    name => { type => 'string' }
                }
            }
        }
    }

    # Map
    {
        id => 'id',     # $track->id
        album => {      # the DBIC accessor
            album => {  # the JSON property - not necessarily the same
                id => 'id',     # $track->album->id
                name => 'name', # $track->album->name
            }
        },
        name => 'name'  # $track->name
    }

=over

=item * The value of the C<album> key is a hashref. C<album> is the name of a
relation on the C<Track> result class.  A hashref is used so that the
C<JSON::Schema::Mapper> object understands that it is not a simple
mapping.

=item * The only key to the hashref is the name of the JSON Schema property that
it will go into, i.e. C<album>.

=item * The value of this key is a hashref because the JSON Schema property
C<'album'> is a nested object.

=item * The inntermost hashref maps the C<id> field of C<album> (the related Album
object) to the C<id> field of C<album> (the JSON object's property); and the
C<name> field of the related C<album> to the C<name> field of the resulting
JSON object.

=back

If the related field is an array, you simply use an array with a hashref inside
it. The following example shows the reverse relation, an Album object with many
Tracks.

    sub _build_json_schema {
        {
            title => 'Album',
            properties => {
                id => { type => 'number' },
                tracks => {
                    type => 'array'
                    items => {
                        type => 'object',
                        properties => {
                            id => { type => 'number' },
                            name => { type => 'name' },
                        }
                    }
                }
            }
        }
    }

    sub _build_map {
        {
            id => 'id',
            tracks => {
                tracks => [ {
                    id => 'id',
                    name => 'name',
                } ]
            }
        }
    }

The main difference is that C<tracks> is a has-many relation; the JSON-Schema
defines it as an array, and so the mapping uses an arrayref. The only difference
is that this tells JSON::Schema::Mapper to expect many results and produce as
many copies as relevant; the arrayref contains a hashref that works just like
the earlier has-one property.

Finally, the spec may be a coderef; in this case it is passed the object in
question and the name of the field. The coderef should return two values: the
name of the JSON field, and the value.

    {
        variable_data => sub {
            my ($obj) = @_;

            # At this location we will get a variableData key in the JSON, and a
            # sub-object mapping the user data's key to its (raw) value.
            return ( variableData => +{ map {; $_->key => $_->value } $obj->variable_data } );
        }
    }

You are given C<$field> so you can use the same subref in multiple situations.
The above example could be rewritten more generically:

    my $map_kv_data =  sub {
        my ($obj, $field) = @_;
        my $json_field = $field =~ s/_(.)/\U$1/gr;

        return ( $json_field => +{ map {; $_->key => $_->value } $obj->$field } );
    }

... then ...

    {
        variable_data => $map_kv_data,
        other_kvp_magic_field => $map_kvp_data,
    }

would produce C<variableData> and C<otherKvpMagicField> in the output. Note in
this case the field name is not used to access the object; your coderef is
passed the object and the field name, not the result of calling the field as a
method.

B<Note:> When the map calls for an array, an arrayref will be dereferenced if
the accessor returns one. This is because the structure requires an inner
mapping of the related objects, which means they must be blessed references on
which further accessors can be called. If you truly want to handle an unblessed
arrayref at this point, you should use a coderef instead of the array
structure.
