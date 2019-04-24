package ECPDF::Component::EF::Reporting::Metadata;
use base qw/ECPDF::BaseClass2/;

__PACKAGE__->defineClass({
    reportObjectTypes => '*',
    uniqueKey         => '*',
    propertyPath      => '*',
    value             => '*',
    pluginObject      => '*'
});

use strict;
use warnings;
use ECPDF::Log;
use JSON;
use Carp;


sub build {
    my ($class, $values) = @_;
}


sub newFromLocation {
    my ($class, $pluginObject, $location) = @_;

    logDebug("Got metadata location: $location");
    my $ec = $pluginObject->newContext()->getEc();
    my $metadata = undef;

    my $retval = undef;
    eval {
        logDebug("Retrieving metadata from $location");
        $metadata = $ec->getProperty($location)->findvalue('//value')->string_value();
        logDebug("Retrieval result: $metadata");
        if ($metadata) {
            logDebug("Metadata found: '$metadata', decoding...");
            $metadata = decode_json($metadata);
            logDebug("Decoded metadata");
            $retval = __PACKAGE__->new({
                value        => $metadata,
                propertyPath => $location
            });
        }
        else {
            logDebug("No metadata found at '$location'");
        }
    };

    logTrace("Returning created metadata");
    return $retval;
}


sub writeIt {
    my ($self) = @_;

    my $pluginObject = $self->getPluginObject();
    my $ec = $pluginObject->newContext()->getEc();
    my $location = $self->getPropertyPath();
    my $values = $self->getValue();
    $ec->setProperty($location => encode_json($values));
    return 1;
}
1;
