=head1 NAME

ECPDF::Component::EF::Reporting::Payloadset

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A payloadset object.

=head1 METHODS

=head2 getReportObhectTypes()

=head2 getPayloads()

=head2 newPayload()

=cut

package ECPDF::Component::EF::Reporting::Payloadset;
use base qw/ECPDF::BaseClass2/;

__PACKAGE__->defineClass({
    ec                => 'ElectricCommander',
    reportObjectTypes => '*',
    payloads          => '*'
});

use strict;
use warnings;
use JSON;

use ECPDF::Helpers qw/bailOut inArray/;
use ECPDF::Component::EF::Reporting::Payload;
use ECPDF::Log;


sub newPayload {
    my ($self, $params) = @_;

    if (!$params->{dependentPayloads}) {
        $params->{dependentPayloads} = [];
    }
    my $payload = ECPDF::Component::EF::Reporting::Payload->new($params);

    my $payloads = $self->getPayloads();
    push @$payloads, $payload;
    return $payload;
}

sub report {
    my ($self) = @_;

    my $payloads = $self->getPayloads();

    my $retval = {};
    for my $row (@$payloads) {
        $row->sendReportToEF();
        $retval->{$row->getReportObjectType()}++;
    }
    return $retval;
}

sub getLastPayload {
    my ($self) = @_;

    my $payloads = $self->getPayloads();
    return $payloads->[-1];
}


1;
