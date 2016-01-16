package Test::Structs;

use strict;
use warnings;
use Struct::Dumb qw/ -named_constructors /;
use Exporter 'import';
our @EXPORT = qw/Album Artist Track/;

struct Album => [qw/
    title tracks year
/];

struct Artist => [qw/
    name albums wikipedia_url
/];

struct Track => [qw/
    title duration
/],
    named_constructor => 0
;
