package ECPDF;

=head1 NAME

ECPDF

=head1 AUTHOR

ElectricCloud

=head1 DESCRIPTION

ECPDF is an Electric Cloud Plugin Development Framework.

This tool has been created to make plugin development easier.

To use it one should extend this class and define pluginInfo which should return a hash reference with following fields:

=over 4

=item * B<pluginName>

A name of the plugin. @PLUGIN_KEY@ could be used to be replaced with plugin name during plugin build-time.

=item * B<pluginVersion>

A version of the plugin. @PLUGIN_VERSION@ could be used to be replaced with version during build-time.

=item * B<configFields>

An array reference, that represents fields that would be used by plugin as a reference to plugin configurations.
For example, one could use ['config', 'configName'] to say that config name could be found in these parameter values.

B<IMPORTANT> This list will be used from left to right, so, in example above configName will be used only if there is no procedure parameter with name 'config'.

=item * B<configLocations>

An array reference with locations of plugin configurations. In all new plugins it will be set to ['ec_plugin_cfgs']. Precedence is the same, as in configFields.

=back

=head1 SYNOPSIS

Example of a plugin main class:

%%%LANG=perl%%%

    package EC::Plugin::NewRest;
    use strict;
    use warnings;
    use base qw/ECPDF/;
    # Service function that is being used to set some metadata for a plugin.
    sub pluginInfo {
        return {
            pluginName    => '@PLUGIN_KEY@',
            pluginVersion => '@PLUGIN_VERSION@',
            configFields  => ['config'],
            configLocations => ['ec_plugin_cfgs']
        };
    }
    sub step_do_something {
        my ($pluginObject) = @_;
        my $context = $pluginObject->newContext();
        # This will show where we are. It could be procedure, pipeline or schedule
        print "Current context is: ", $context->getRunContext(), "\n";
        # This will get a step parameters.
        # $params now will be an L<ECPDF::StepParameters> object.
        my $params = $context->getStepParameters();
        # This gets $headers parameter that is being stored under request_headers field of procedure.
        # To get value of this parameter one should 1. get parameter object 2. get a value if it is defined
        my $headers = $params->getParameter('request_headers');
        # This will return a config values for current procedure including credentials.
        # For configuration lookup see section above.
        my $configValues = $context->getConfigValues();
        # This creates a step result object, which handles actions that should be done during or after step execution
        my $stepResult = $context->newStepResult();
        # schedule setting a job step outcome to warning
        $stepResult->setJobStepOutcome('warning');
        # schedule setting a whole job summary:
        $stepResult->setJobSummary("See, this is a whole job summary");
        # schedule setting a current jobstep summary
        $stepResult->setJobStepSummary('And this is a job step summary');
        # abd, finally, apply all scheduled settings.
        $stepResult->apply();
    }

%%%LANG%%%

=head1 METHODS

=cut

use base qw/ECPDF::BaseClass2/;
use ECPDF::Types;

__PACKAGE__->defineClass({
    pluginName      => ECPDF::Types::Scalar(),
    pluginVersion   => ECPDF::Types::Scalar(),
    configFields    => ECPDF::Types::ArrayrefOf(ECPDF::Types::Scalar()),
    configLocations => ECPDF::Types::ArrayrefOf(ECPDF::Types::Scalar()),,
    contextFactory  => ECPDF::Types::Reference('ECPDF::ContextFactory'),
    pluginValues    => ECPDF::Types::Reference('HASH'),
    contextObject   => ECPDF::Types::Reference('ECPDF::Context'),
});

use strict;
use warnings;

use Carp;
use Data::Dumper;

use ECPDF::Service::Bootstrap;
use ECPDF::ContextFactory;
use ECPDF::ComponentManager;


our $VERSION = '1.0.12';

# TODO: Explain this later.
BEGIN {
    select (STDERR);
    $| = 1;
    select (STDOUT);
    $| = 1;
};

sub classDefinition {
    return {

    };
}

=head2 newContext()

=head3 Description

Creates L<ECPDF::Context> object. Does not require any additional parameters.

Please, note, that this function always creates a new context object.

If you want to use already existing context object, consider to use a getContext() method.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item L<ECPDF::Context>

=back

%%%LANG=perl%%%

    my $context = $pluginObject->newContext();

%%%LANG%%%

=cut


sub newContext {
    my ($pluginObject) = @_;

    my $context = $pluginObject->getContextFactory()->newContext($pluginObject);
    return $context;
}


=head2 getContext()

=head3 Description

This method returns already created L<ECPDF::Context> object. Does not require any additional parameters.

If this method is being used first time, it creates new context object and returns it. Each next call will return exactly this object.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item L<ECPDF::Context>

=back

%%%LANG=perl%%%

    my $context = $pluginObject->getContext();

%%%LANG%%%

=cut

sub getContext {
    my ($pluginObject) = @_;

    my $context = $pluginObject->getContextObject();
    if ($context) {
        return $context;
    }
    $context = $pluginObject->getContextFactory()->newContext($pluginObject);
    $pluginObject->setContextObject($context);
    return $context;
}


# this function is here to be a placeholder for real pluginInfo function that is being defined by plugin object.
sub pluginInfo {}

sub runStep {
    my ($class, $procedureName, $stepName, $function) = @_;

    if (!$class->can($function)) {
        croak "Class $class does not define function $function\n";
    }
    if (!$class->can('pluginInfo')) {
        croak "Class $class does not have a pluginInfo function defined\n";
    }
    my $pluginInfo = $class->pluginInfo();

    # TODO: add validation for pluginInfo fields.
    my $ecpdf = $class->new({
        pluginName      => $pluginInfo->{pluginName},
        pluginVersion   => $pluginInfo->{pluginVersion},
        configFields    => $pluginInfo->{configFields},
        configLocations => $pluginInfo->{configLocations},
        contextFactory  => ECPDF::ContextFactory->new({
            procedureName => $procedureName,
            stepName      => $stepName
        })
    });

    my $context           = $ecpdf->getContext();
    my $runtimeParameters = $context->getRuntimeParameters();
    my $stepResult        = $context->newStepResult();

    # if pluginvalues has been passed, it will be added to plugin object.
    if ($pluginInfo->{pluginValues}) {
        $ecpdf->setPluginValues($pluginInfo->{pluginValues});
    }

    my $retval = $ecpdf->$function($runtimeParameters, $stepResult);
    $stepResult->applyIfNotApplied();
    return $retval;
}


=head2 getPluginProjectName()

=head3 Description

This method returns a complete name of your plugin with version as string.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (String) PluginName-PluginVersion;

=back

%%%LANG=perl%%%

    my $pluginProjectName = $pluginObject->getPluginProjectName();

%%%LANG%%%

=cut


sub getPluginProjectName {
    my ($self) = @_;

    my $pluginProjectName = sprintf(
        '%s-%s',
        $self->getPluginName(),
        $self->getPluginVersion()
    );

    return $pluginProjectName;
}

=head1 SEE ALSO

=head2 L<ECPDF::Context>

=head2 L<ECPDF::StepResult>

=head2 L<ECPDF::Config>

=cut

1;
