package ECPDF::Component::EF::Reporting::MetadataFactory;
use base qw/ECPDF::BaseClass2/;
__PACKAGE__->defineClass({
    pluginObject      => '*',
    reportObjectTypes => '*',
    propertyPath      => '*',
    payloadKeys       => '*',
    uniqueKey         => '*'
});

use strict;
use warnings;
use ECPDF::Component::EF::Reporting::Metadata;
use ECPDF::Log;
use ECPDF::Helpers qw/bailOut/;
use Carp;
use Data::Dumper;


sub newMetadataFromPayload {
    my ($self, $payload) = @_;

    # TODO: Add class fields validation here.
    my $keys = $self->getPayloadKeys();
    my $uniqueKey = $self->getUniqueKey();

    my $values = {};
    my $payloadValues = $payload->getValues();
    for my $key (@$keys) {
        if (!exists $payloadValues->{$key}) {
            bailOut("Key $key does not exist in payload, can't create metadata");
        }
        $values->{$key} = $payloadValues->{$key};
    }
    my $metadata = ECPDF::Component::EF::Reporting::Metadata->new({
        reportObjectTypes => $self->getReportObjectTypes(),
        uniqueKey => $self->getUniqueKey(),
        propertyPath => $self->getPropertyPath(),
        value => $values,
        pluginObject => $self->getPluginObject()
    });

    return $metadata;
}

sub buildMetadataName {
    my ($self) = @_;

    my $reportObjectTypes = $self->getReportObjectTypes();
    # TODO: Move this validation to validate() function later, during cleanup phase.
    if (ref $reportObjectTypes ne 'ARRAY') {
        croak "Array reference is required";
    }
    my $po = $self->getPluginObject();
    if (!$po) {
        croak "Missing plugin object for metadata name.";
    }
    my $pluginName = $po->getPluginName();
    my $uniqueKey = $self->getUniqueKey();
    my $reportObjectTypeString = join('-', sort {$a cmp $b} @$reportObjectTypes);

    my $metadataName = sprintf('%s-%s-%s', $pluginName, $uniqueKey, $reportObjectTypeString);

    return $metadataName;
}


sub newFromLocation {
    my ($self) = @_;

    my $location = $self->getPropertyPath();
    logDebug("Got property path: $location");
    my $metadata = ECPDF::Component::EF::Reporting::Metadata->newFromLocation(
        $self->getPluginObject(), $location
    );
    logDebug("Metadata:", Dumper $metadata);
    if (!$metadata) {
        return undef;
    }

    my $payloadKeys = $self->getPayloadKeys();
    my $metadataValue = $metadata->getValue();

    for my $k (@$payloadKeys) {
        if (!exists $metadataValue->{$k}) {
            bailOut "Declared metadata key '$k' is not present in metadata. Aborting.";
        }
    }
    return $metadata;
}
1;
