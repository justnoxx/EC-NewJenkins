# this component should be extended by user component, and then be loaded using our standard mechanism.
# 
package ECPDF::Component::EF::Reporting;
use strict;
use warnings;
use base qw/ECPDF::Component::EF/;

our $PREVIEW_MODE_ENABLED = 0;

__PACKAGE__->defineClass({
    metadataUniqueKey     => 'str',
    # an array reference of strings for report object types, like ['build', 'quality'];
    reportObjectTypes     => '*',
    initialRetrievalCount => 'str',
    pluginName            => 'str',
    pluginObject          => '*',
    transformer           => '*',
    payloadKeys           => '*'
});

use Data::Dumper;
use Carp;
use ECPDF::Component::EF::Reporting::Dataset;
use ECPDF::Component::EF::Reporting::Payloadset;
use ECPDF::Component::EF::Reporting::Engine;
use ECPDF::Helpers qw/bailOut/;
use ECPDF::Log;
use ECPDF::Component::EF::Reporting::Metadata;
use ECPDF::Component::EF::Reporting::MetadataFactory;
use ECPDF::Component::EF::Reporting::Transformer;


sub init {
    my ($class, $pluginObject, $initParams) = @_;

    my $self = ECPDF::Component::EF::Reporting->new();
    $self->setPluginName($pluginObject->getPluginName());

    if (!$initParams->{reportObjectTypes}) {
        bailOut("reportObjectTypes is mandatory");
    }

    if (!ref $initParams->{reportObjectTypes} || ref $initParams->{reportObjectTypes} ne 'ARRAY') {
        bailOut("ReportObjectTypes are expected to be an ARRAY reference.");
    }
    $self->setReportObjectTypes($initParams->{reportObjectTypes});
    if ($initParams->{initialRetrievalCount}) {
        $self->setInitialRetrievalCount($initParams->{initialRetrievalCount});
    }

    $self->setPluginObject($pluginObject);
    if ($initParams->{metadataUniqueKey}) {
        $self->setMetadataUniqueKey($initParams->{metadataUniqueKey});
    }
    if ($initParams->{payloadKeys}) {
        $self->setPayloadKeys($initParams->{payloadKeys});
    }
    # TODO: think about potential pitfalls of this.
    if ($class ne __PACKAGE__) {
        bless $self, $class;
    };

    my $runtimeParameters = $pluginObject->newContext()->getRuntimeParameters();

    if ($runtimeParameters->{transformScript}) {
        my $transformer = ECPDF::Component::EF::Reporting::Transformer->new({
            pluginObject    => $pluginObject,
            transformScript => $runtimeParameters->{transformScript}
        });
        $transformer->load();
        $self->setTransformer($transformer);
    }

    if ($runtimeParameters->{previewMode}) {
        $PREVIEW_MODE_ENABLED = 1;
    }
    return $self;
}

sub isPreview {
    return $PREVIEW_MODE_ENABLED;
}

sub buildMetadataLocation {
    my ($self) = @_;

    my $po = $self->getPluginObject();
    my $context = $po->newContext();

    my $runtimeParameters = $context->getRuntimeParameters();
    if ($runtimeParameters->{metadataPropertyPath}) {
        logInfo("Metadata location was set in the procedure parameters to: $runtimeParameters->{metadataPropertyPath}\n");
        return $runtimeParameters->{metadataPropertyPath};
    }
    my $runContext = $context->getRunContext();
    my $projectName = $context->getCurrentProjectName();

    my $location = '';
    logInfo("Current run context is: '$runContext'");
    if ($runContext eq 'schedule') {
        my $scheduleName = $context->getCurrentScheduleName();
        $location = sprintf('/projects/%s/schedules/%s/ecreport_data_tracker', $projectName, $scheduleName);
    }
    else {
        $location = sprintf('/projects/%s/ecreport_data_tracker', $projectName);
    }

    logInfo "Built metadata location: $location";
    return $location;
}


sub CollectReportingData {
    my ($self) = @_;

    my $metadataFactory = ECPDF::Component::EF::Reporting::MetadataFactory->new({
        pluginObject      => $self->getPluginObject(),
        reportObjectTypes => $self->getReportObjectTypes(),
        propertyPath      => $self->buildMetadataLocation(),
        payloadKeys       => $self->getPayloadKeys(),
        uniqueKey         => $self->getMetadataUniqueKey()
    });
    $metadataFactory->setPropertyPath($metadataFactory->getPropertyPath . '/' . $metadataFactory->buildMetadataName());
    logInfo("Metadata Property Path: " . $metadataFactory->getPropertyPath());
    logDebug("Reference inside of CollectReportingData: ", ref $self);
    my $pluginObject = $self->getPluginObject();
    my $stepResult = $pluginObject->newContext()->newStepResult();
    if (ECPDF::Component::EF::Reporting->isPreview()) {
        $stepResult->setJobStepSummary("Preview mode is in effect. Without it you would have:");
    }
    my $runtimeParameters = $pluginObject->newContext()->getRuntimeParameters();
    if (!$runtimeParameters->{initialRetrievalCount}) {
        $runtimeParameters->{initialRetrievalCount} = 0;
    }
    # 1. Getting metadata from location.
    logDebug("Checking for metadata");
    my $metadata = $metadataFactory->newFromLocation();
    logDebug("Metadata from property: ", Dumper $metadata);
    if ($metadata) {
        logInfo("Metadata exists!");
        my $lastRecord = $self->getLastRecord($pluginObject);
        $lastRecord = [$lastRecord];
        my $transformer = $self->getTransformer();
        if ($transformer) {
            logInfo "Transformer is present.";
            for my $r (@$lastRecord) {
                $transformer->transform($r);
            }
        }
        my $payloadset = $self->buildPayloadset(
            $pluginObject, $self->buildDataset(
                $pluginObject, $lastRecord
            )
        );
        my $lastMetadata = $metadataFactory->newMetadataFromPayload($payloadset->getLastPayload());
        # they are equal, return 1, reported data is actual;
        if ($self->compareMetadata($metadata, $lastMetadata) == 0) {
            logInfo("Up to date, nothing to sync.");
            $stepResult->setJobStepSummary("Up to date, nothing to sync");
            $stepResult->apply();
            return 1;
        }
    }

    my $records;
    if ($metadata) {
        $records = $self->getRecordsAfter($pluginObject, $metadata);
    }
    else {
        logDebug("No metadata, retrieving records");
        $records = $self->initialGetRecords($pluginObject, $runtimeParameters->{initialRecordsCount});
        logDebug("Records:", Dumper $records);
    }

    # now, we're applying transform script
    my $transformer = $self->getTransformer();
    if ($transformer) {
        logInfo "Transformer is present.";
        for my $r (@$records) {
            $transformer->transform($r);
        }
    }
    # end of transformation.
    #    exit 0;
    # 2. get records after date, or all records, or with limit

    # 3. build dataset from records to be used as source for payloadset
    # mappings are being applied right there
    my $dataset = $self->buildDataset($pluginObject, $records);

    # 4. Create payloadset.
    # transform script will be applied to each payload object.
    my $payloads = $self->buildPayloadset($pluginObject, $dataset);
    $self->prepareAndValidatePayloads($payloads);

    #$payloads->validate();
    # exit 0;
    # $payloads->convert();
    # $payloads->validate();
    # 5. finally report
    my $reportingResult = $payloads->report();
    logDebug("Reporting result: ", Dumper $reportingResult);
    for my $reportType (keys %$reportingResult) {
        $stepResult->setJobStepSummary("Payloads sent:\nPayloads of type $reportType sent: $reportingResult->{$reportType}");
    }
    $stepResult->apply();
    my $newMetadata = $metadataFactory->newMetadataFromPayload($payloads->getLastPayload());
    $newMetadata->writeIt();
    # my $newMetadata = $payloads->report();
    exit 0;
    # 6. Write new metadata.
    # $newMetadata->writeIt();

    return 1;
}


sub prepareAndValidatePayloads {
    my ($self, $payloads) = @_;

    if (ref $payloads ne 'ECPDF::Component::EF::Reporting::Payloadset') {
        bailOut("PayloadSet are expected to be an ECPDF::Component::EF::Reporting::Payloadset reference. Got: " . ref $payloads);
    }

    my $pluginObject = $self->getPluginObject();
    my $ec = $pluginObject->newContext()->getEc();
    my $reportingEngine = ECPDF::Component::EF::Reporting::Engine->new({
        ec => $ec
    });
    my $preparedPayloads = $payloads->getPayloads();

    for my $row (@$preparedPayloads) {
        logDebug "Payload BEFORE conversion: " . Dumper $row;
        my $type = $row->getReportObjectType();
        my $values = $row->getValues();
        my $definition = $reportingEngine->getPayloadDefinition($type);
        for my $k (keys %$values) {
            if (!$definition->{$k}) {
                logWarning("$k that is present in payload is not present in $type object definition. Removing it from payload.");
                delete $values->{$k};
                next;
            }
            $values->{$k} = $self->validateAndConvertRow($k, $definition->{$k}->{type}, $values->{$k});
        }
        logDebug "Payload AFTER conversion: " . Dumper $row;
    }
    return $self;
}

sub validateAndConvertRow {
    my ($self, $field, $type, $value) = @_;

    if ($type eq 'STRING') {
        return $value;
    }
    elsif ($type eq 'NUMBER') {
        # TODO: Improve validation here
        if ($value !~ m/^[0-9\-]+$/) {
            bailOut("Expected a number value, got: $value");
        }
        return $value +0;
    }
    elsif ($type eq 'DATETIME') {
        if ($value !~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,4})?Z$/) {
            bailOut "DATETIME field $field has incorrect value: $value. Expected value in Zulu timezone, like:YYYY-MM-DDTHH:MM:SS.sssZ\n";
        }
        return $value;
    }
    else {
        logInfo("Validation of field '$field' with type '$type' is not supported yet by ECPDF-SDK.");
    }
    return $value;
}

sub newDataset {
    my ($self, $reportObjectTypes, $data) = @_;

    $data ||= [];
    if (!$reportObjectTypes) {
        croak "Missing reportObjectTypes for newDataset";
    }

    my $dataset = ECPDF::Component::EF::Reporting::Dataset->new({
        reportObjectTypes => $reportObjectTypes,
        data              => $data
    });

    return $dataset;
};


sub newPayloadset {
    my ($self, $reportObjectTypes, $payloads) = @_;

    $payloads ||= [];
    if (!$reportObjectTypes) {
        croak "Missing reportObjectTypes for newPayloadset";
    }

    my $pluginObject = $self->getPluginObject();
    my $ec = $pluginObject->newContext()->getEc();

    my $payloadset = ECPDF::Component::EF::Reporting::Payloadset->new({
        reportObjectTypes => $reportObjectTypes,
        payloads          => $payloads,
        ec                => $ec,
    });

    return $payloadset;
}


sub newMetadata {};
1;
