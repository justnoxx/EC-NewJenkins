=head1 NAME

ECPDF::Component::EF::Reporting::Data

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A data object.

=head1 METHODS

=head2 getReportObjectType()

=head3 Description

Returns a report object type for current data.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (String) Report object type for current data.

=back

=head3 Exceptions

=over 4

=item None

=back

=head3 Usage

%%%LANG=perl%%%

    my $reportObhectType = $data->getReportObjectType();

%%%LANG%%%



=head2 getValues()

=head3 Description

Returns a values for the current data.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (HASH ref) A values for the current data.

=back

=head3 Usage

%%%LANG=perl%%%

    my $values = $data->getValues();

%%%LANG%%%


=cut

package ECPDF::Component::EF::Reporting::Data;
use base qw/ECPDF::BaseClass2/;
use ECPDF::Types;

__PACKAGE__->defineClass({
    reportObjectType => ECPDF::Types::Scalar(),
    values           => ECPDF::Types::Reference('HASH'),
    dependentData    => ECPDF::Types::ArrayrefOf(ECPDF::Types::Reference('ECPDF::Component::EF::Reporting::Data')),
});

use strict;
use warnings;
use ECPDF::Log;
use ECPDF::Helpers qw/bailOut/;

sub createNewDependentData {
    my ($self, $reportObjectType, $values) = @_;
    # TODO: Add validation of reportobjectype.
    if (!$reportObjectType) {
        bailOut("mising reportObjectType parameter for addDependentData");
    }
    if (!$values) {
        $values = {};
    }
    my $dep = $self->getDependentData();
    my $data = __PACKAGE__->new({
        reportObjectType => $reportObjectType,
        values => $values,
        dependentData => [],
    });
    push @$dep, $data;
    return $data;
}

sub addDependentData {
    my ($self, $data) = @_;

    if (!$data || ref $data ne __PACKAGE__) {
        bailOut("Data parameter is mandatory and should be a " . __PACKAGE__ . " reference");
    }

    my $dep = $self->getDependentData();
    push @$dep, $data;

    return $self;
}

=head2 addOrUpdateValue

=head3 Description

Adds or updates a value for the current data object.

=head3 Parameters

=over 4

=item (Required)(String) Key for the data.

=item (Required)(String) Value for the data.

=back

=head3 Returns

=over 4

=item Reference to the current ECPDF::Component::EF::Reporting::Data

=back

=head3 Exceptions

=over 4

=item None

=back

=head3 Usage

%%%LANG=perl%%%

    $data->addOrUpdateValue('key', 'value')

%%%LANG%%%

=cut


sub addOrUpdateValue {
    my ($self, $key, $value) = @_;

    my $currentValues = $self->getValues();

    $currentValues->{$key} = $value;
    return $self;
}


=head2 addValue

=head3 Description

Adds a new value to the data values, falls with exceptions if provided key already exists.

=head3 Parameters

=over 4

=item (Required)(String) Key for the data.

=item (Required)(String) Value for the data.

=back

=head3 Returns

=over 4

=item Reference to the current ECPDF::Component::EF::Reporting::Data

=back

=head3 Exceptions

=over 4

=item Fatal error if field already exists.

=back

=head3 Usage

%%%LANG=perl%%%

    $data->addValue('key', 'value')

%%%LANG%%%

=cut


sub addValue {
    my ($self, $key, $value) = @_;

    my $currentValues = $self->getValues();

    if (exists $currentValues->{$key}) {
        bailOut("Key $key is already exists. Can't add");
    }
    $currentValues->{$key} = $value;
    return $self;
}


=head2 updateValue

=head3 Description

Updates a value for current data values. Fatal error if value does not exist.

=head3 Parameters

=over 4

=item (Required)(String) Key for the data.

=item (Required)(String) Value for the data.

=back

=head3 Returns

=over 4

=item Reference to the current ECPDF::Component::EF::Reporting::Data

=back

=head3 Exceptions

=over 4

=item Fatal exception if value does not exist.

=back

=head3 Usage

%%%LANG=perl%%%

    $data->updateValue('key', 'value')

%%%LANG%%%

=cut


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
