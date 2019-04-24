package ECPDF::Component::EF::Reporting::Dataset;
use base qw/ECPDF::BaseClass2/;

__PACKAGE__->defineClass({
    reportObjectTypes => '*',
    data              => '*',
});

use ECPDF::Helpers qw/bailOut inArray/;
use strict;
use warnings;

sub newData {
    my ($self, @params) = @_;

    return ECPDF::Component::EF::Reporting::Data->new(@params);
}


package ECPDF::Component::EF::Reporting::Data;
use base qw/ECPDF::BaseClass2/;
__PACKAGE__->defineClass({
    reportObjectType => 'str',
    values => '*',
    dependentData => '*',
});

use strict;
use warnings;

sub addDependentData {
    my ($self, $reportObjectType, $data) = @_;

    my $dep = $self->getDependentData();
    push @$dep, $data;
    return $self;
}

1;
