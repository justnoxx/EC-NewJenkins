package ECPDF::Component::EF;
use base qw/ECPDF::Component/;

__PACKAGE__->defineClass({
    pluginObject => '*'
});

use strict;
use warnings;

sub isEFComponent {
    return 1;
}

1;

