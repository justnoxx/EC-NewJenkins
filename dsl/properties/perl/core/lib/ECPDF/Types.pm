package ECPDF::Types;
# use base qw/Exporter/;

use strict;
use warnings;
use Data::Dumper;

use ECPDF::Helpers qw/bailOut/;

use ECPDF::Types::Any;
use ECPDF::Types::Reference;
use ECPDF::Types::Scalar;
use ECPDF::Types::Enum;
use ECPDF::Types::ArrayrefOf;

sub Reference {
    my (@refs) = @_;

    return ECPDF::Types::Reference->new(@refs);
}

sub Enum {
    my (@vals) = @_;

    return ECPDF::Types::Enum->new(@vals);
}

sub Scalar {
    my ($value) = @_;
    return ECPDF::Types::Scalar->new($value);
}

sub Any {
    return ECPDF::Types::Any->new();
}

sub ArrayrefOf {
    my (@refs) = @_;

    return ECPDF::Types::ArrayrefOf->new(@refs);
}

1;
