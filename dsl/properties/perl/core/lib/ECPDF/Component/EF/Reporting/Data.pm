=head1 NAME

ECPDF::Component::EF::Reporting::Data

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A data object.

=head1 METHODS

=head2 getReportObhectType()

=head2 getValues()

=head2 getDependentData()

=head2 addDependentData()

=cut

package ECPDF::Component::EF::Reporting::Data;
use base qw/ECPDF::BaseClass2/;
__PACKAGE__->defineClass({
    reportObjectType => 'str',
    values => '*',
    dependentData => '*',
});

use strict;
use warnings;
use ECPDF::Log;
use ECPDF::Helpers qw/bailOut/;

sub addDependentData {
    my ($self, $reportObjectType, $data) = @_;

    my $dep = $self->getDependentData();
    push @$dep, $data;
    return $self;
}

sub addOrUpdateValue {
    my ($self, $key, $value) = @_;

    my $currentValues = $self->getValues();

    $currentValues->{$key} = $value;
    return $self;
}

sub addValue {
    my ($self, $key, $value) = @_;

    my $currentValues = $self->getValues();

    if (exists $currentValues->{$key}) {
        bailOut("Key $key is already exists. Can't add");
    }
    $currentValues->{$key} = $value;
    return $self;
}

sub updateValue {
    my ($self, $key, $value) = @_;

    my $currentValues = $self->getValues();

    if (!exists $currentValues->{$key}) {
        bailOut("Key $key does not exist. Can't update.");
    }
    $currentValues->{$key} = $value;
    return $self;
}


1;
