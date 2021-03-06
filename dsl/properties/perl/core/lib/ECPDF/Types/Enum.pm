package ECPDF::Types::Enum;
use strict;
use warnings;

sub new {
    my ($class, @values) = @_;

    my $self = {
        values => \@values
    };
    bless $self, $class;
    return $self;
}


sub match {
    my ($self, $value) = @_;

    for my $v (@{$self->{values}}) {
        return 1 if $value eq $v;
    }

    return 0;
}


sub describe {
    my ($self) = @_;

    my $values = $self->{values};

    my $strValues = join ', ', @$values;
    return "an one of $strValues";
}

1;
