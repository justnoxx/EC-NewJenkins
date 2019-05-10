=head1 NAME

ECPDF::Component::EF::Reporting::Dataset

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A dataset object.

=head1 METHODS

=head2 getReportObhectTypes()

=head2 getData()

=head2 newData()

=cut

package ECPDF::Component::EF::Reporting::Dataset;
use base qw/ECPDF::BaseClass2/;

__PACKAGE__->defineClass({
    reportObjectTypes => '*',
    data              => '*',
});

use strict;
use warnings;

use Data::Dumper;

use ECPDF::Helpers qw/bailOut inArray/;
use ECPDF::Component::EF::Reporting::Data;
use ECPDF::Log;

sub newData {
    my ($self, $params) = @_;

    if (!$params->{values}) {
        $params->{values} = {};
    }
    if (!$params->{dependentData}) {
        $params->{dependentData} = [];
    }
    my $data = ECPDF::Component::EF::Reporting::Data->new($params);
    logTrace("Data object address:  $data");
    my $dataRef = $self->getData();
    logTrace("Dataset object BEFORE inserting into dataset: ", Dumper $dataRef);
    push @$dataRef, $data;
    logTrace("Dataset object AFTER inserting into dataset: ", Dumper $dataRef);
    return $data;
}

1;
