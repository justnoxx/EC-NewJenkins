=head1 NAME

ECPDF::Component::EF::Reporting::Payload

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A payload object.

=head1 METHODS

TBD;

=cut


package ECPDF::Component::EF::Reporting::Payload;
use base qw/ECPDF::BaseClass2/;
__PACKAGE__->defineClass({
    reportObjectType => 'str',
    values => '*',
    dependentPayloads => '*',
});

use strict;
use warnings;
use JSON;
use ElectricCommander;
use ECPDF::Helpers qw/bailOut/;
use ECPDF::Log;

# local $| = 1;

my $ELECTRIC_COMMANDER_OBJECT;

sub setEc {
    my ($ec) = @_;

    # TODO: Improve this to force static context.
    # if (!ref $ec) {

    # }
    if (!$ec) {
        bailOut "Missing EC parameter";
    }
    if (ref $ec ne 'ElectricCommander') {
        bailOut "Expected an ElectricCommander reference";
    }

    $ELECTRIC_COMMANDER_OBJECT = $ec;
    return $ec;
}


sub getEc {
    return $ELECTRIC_COMMANDER_OBJECT if $ELECTRIC_COMMANDER_OBJECT;

    logDebug "ElectricCommander object has not been set for " . __PACKAGE__ . ", creating default object.";
    my $ec = ElectricCommander->new();
    return setEc($ec);
}


sub encode {
    my ($self) = @_;

    my $encodedPayload = encode_json($self->getValues());
    return $encodedPayload;
}

sub sendAllReportsToEF {
    my ($self) = @_;

    my $result = $self->sendReportToEF();

    my $dependentPayloads = $self->getDependentPayloads();

    unless (@$dependentPayloads) {
        return $result;
    }

    my $result2 = [];
    for my $dp (@$dependentPayloads) {
        my $tempResult = $dp->sendReportToEF();
        push @$result2, $tempResult;
    }

    # TODO: add error handling here.
    return $result2;
}
sub sendReportToEF {
    my ($self) = @_;

    my $ec = $self->getEc();
    my $retval = {
        ok => 1,
        message => '',
    };

    my $payload = $self->getValues();
    my $reportObjectType = $self->getReportObjectType();
    my $encodedPayload = $self->encode();
    logInfo "Encoded payload to send: $encodedPayload";

    if (ECPDF::Component::EF::Reporting->isPreview()) {
        logInfo("Preview mode is enabled, nothing to send");
        return 1;
    }

    my $xpath = $ec->sendReportingData({
        payload => $encodedPayload,
        reportObjectTypeName => $reportObjectType
    });

    my $errorCode = $xpath->findvalue('//error/code')->string_value();
    if ($errorCode) {
        $retval->{ok} = 0;
        $retval->{message} = $errorCode;
        logError "Error occured during reporting: " . Dumper $retval;
        if (!$retval->{message}) {
            logError "No error message found. Full error xml: $xpath->{_xml}";
        }
    }
    return $retval;
}

# TODO: Implement addition of dependent payload.
sub addDependentPayload {
    my ($self, $reportObjectType) = @_;

    return $self;
}

1;

