package ECPDF::Component::EF::Reporting::Engine;
use base qw/ECPDF::BaseClass2/;
__PACKAGE__->defineClass({
    ec => 'ElectricCommander'
});

use strict;
use warnings;
use Carp;
use ECPDF::Log;
use ECPDF::Helpers qw/bailOut/;

sub getReportObjectTypes {
    my ($self, $reportObjectType) = @_;

    my $ec = $self->getEc();
    my $resp = $ec->getReportObjectTypes();
    my $retval = [];
    for my $node ($resp->findnodes('//reportObjectTypeName')) {
        push @$retval, $node->string_value();
    }

    return $retval;
}

sub getPayloadDefinition {
    my ($self, $reportObjectType) = @_;

    if (!$reportObjectType) {
        bailOut("Report object type parameter is mandatory");
    }
    my $ec = $self->getEc();
    my $reportObjectTypes = $self->getReportObjectTypes();

    my $ok = 0;
    for my $row (@$reportObjectTypes) {
        $ok++ && last if $reportObjectType eq $row;
    }

    unless ($ok) {
        bailOut("Report Object Type '$reportObjectType' does not exist.");
    }

    my $payloadDefinition = {};

    my $xpath = $ec->getReportObjectAttributes($reportObjectType);

    for my $node ($xpath->findnodes('//reportObjectAttribute')) {
        my $attributeName = $node->findvalue('reportObjectAttributeName')->string_value();
        my $dataType = $node->findvalue('type')->string_value();
        my $isRequired = $node->findvalue('required')->string_value() + 0;

        $payloadDefinition->{$attributeName}->{name} = $attributeName;
        $payloadDefinition->{$attributeName}->{type} = $dataType;
        $payloadDefinition->{$attributeName}->{required} = $isRequired;
    }

    return $payloadDefinition;
}




1;
