package ECPDF::Component::EF::Reporting::Transformer;
use base qw/ECPDF::BaseClass2/;
__PACKAGE__->defineClass({
    pluginObject    => '*',
    transformScript => 'str',
    transformer     => '*',
});


use strict;
use warnings;
use ECPDF::Log;
use ECPDF::Helpers qw/bailOut/;

sub load {
    my ($self) = @_;

    my $transformScript = $self->getTransformScript();
    if (!$transformScript) {
        logInfo("No transform script has been provided");
        return $self;
    }

    my $tempTransformer = "package EC::Mapper::Transformer;\n" .
        q|sub transform {my ($payload) = @_; return $payload}| . "\n" .
        q|no warnings 'redefine';| .
        $transformScript .
        "1;\n";


    eval $tempTransformer;
    if ($@) {
        bailOut("Error occured during loading of transform script: $@\n");
    }
    my $transformer = {};
    my $blessedTransformer = bless $transformer, "EC::Mapper::Transformer";

    $self->setTransformer($blessedTransformer);
    return $self;
}


sub transform {
    my ($self, $record) = @_;

    logInfo("Transformer object:", Dumper $self);
    my $blessedTransformer = $self->getTransformer();
    return $blessedTransformer->transform($record);
}


1;
