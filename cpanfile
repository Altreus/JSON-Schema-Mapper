requires 'Moose';
requires 'JSON::MaybeXS';
requires 'Scalar::IfDefined';

on test => sub {
    requires 'Struct::Dumb';
    requires 'List::Util';
};
