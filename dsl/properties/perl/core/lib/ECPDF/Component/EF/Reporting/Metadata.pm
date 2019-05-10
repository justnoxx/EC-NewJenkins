=head1 NAME

ECPDF::Component::EF::Reporting::Metadata

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A metadata object for ECPDF::Component::EF::Reporting system.

=head1 METHODS


=head2 getValue()

=head3 Descripton

Returns decoded metadata value.

=head3 Parameters

=head3 Returns

=head3 Exceptions

=head3 Usage


=head2 getUniqueKey()

=head3 Descripton

Returns unique key for current metadata object.

=head3 Parameters

=head3 Returns

=head3 Exceptions

=head3 Usage



=head2 getReportObjectTypes()

=head3 Descripton

Returns report object types for current metadata object.

=head3 Parameters

=head3 Returns

=head3 Exceptions

=head3 Usage


=head2 getPropertyPath()

=head3 Descripton

Returns property path where metadata is stored or is to be stored.

=head3 Parameters

=head3 Returns

=head3 Exceptions

=head3 Usage



=cut

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
    my $ec = $pluginObject->getContext()->getEc();
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
    my $ec = $pluginObject->getContext()->getEc();
    my $location = $self->getPropertyPath();
    my $values = $self->getValue();
    $ec->setProperty($location => encode_json($values));
    return 1;
}
1;
