package ECPDF::Component::EF;
use base qw/ECPDF::Component/;
use ECPDF::Types;

__PACKAGE__->defineClass({
    pluginObject => ECPDF::Types::Any(),
});

use strict;
use warnings;

sub isEFComponent {
    return 1;
}

1;

