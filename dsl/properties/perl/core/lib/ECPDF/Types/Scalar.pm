package ECPDF::Types::Scalar;
use strict;
use warnings;

sub new {
    my ($class, $value) = @_;

    $value ||= '';

    my $self = {
        value => $value
    };
    bless $self, $class;
    return $self;
}

sub match {
    my ($self, $value) = @_;

    if (ref $value) {
        return 0;
    }
    if ($self->{value} && $self->{value} eq $value) {
        return 1;
    }
    if (!$self->{value}) {
        return 1;
    }
    return 0;
}


sub describe {
    my ($self) = @_;

    if (!$self->{value}) {
        return "a scalar value";
    }
    return "a scalar value: '$self->{value}'";
}


1;
