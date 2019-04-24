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
    my ($self, @params) = @_;

    return ECPDF::Component::EF::Reporting::Payload->new(@params);
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

# sub validate {
#     my ($self) = @_;

#     my $payloads = $self->getPayloads();

#     for my $p (@$payloads) {
#         my $values = $p->getValues();

#         for my $k (keys %$values) {};
#     }
# }

1;
