package EC::Plugin::NewJenkins::Reporting;
use Data::Dumper;
use base qw/ECPDF::Component::EF::Reporting/;
use ECPDF::Log;
use strict;
use warnings;

sub compareMetadata {
    # TODO: Think about pluginobject as 2nd parameter, before $metadata1.
    my ($self, $metadata1, $metadata2) = @_;
    my $value1 = $metadata1->getValue();
    my $value2 = $metadata2->getValue();
    return $value1->{buildNumber} <=> $value2->{buildNumber};
}


sub initialGetRecords {
    my ($self, $pluginObject, $limit) = @_;

    my $runtimeParameters = $pluginObject->newContext()->getRuntimeParameters();
    logDebug("Initial Get Records runtime parameters:", Dumper $runtimeParameters);
    my $lastNumber = $pluginObject->getLastBuildNumber($runtimeParameters->{jobName});
    logDebug("Initial Get Records last build number: $lastNumber");
    my $records = $pluginObject->getJobDetailsRanged($runtimeParameters->{jobName}, 0, $lastNumber, $limit);
    return $records;
}


sub getRecordsAfter {
    my ($self, $pluginObject, $metadata) = @_;

    my $runtimeParameters = $pluginObject->newContext()->getRuntimeParameters();
    my $lastNumber = $pluginObject->getLastBuildNumber($runtimeParameters->{jobName});
    my $metadataValues = $metadata->getValue();
    logDebug("Got metadata value in getRecordsAfter:", Dumper $metadataValues);
    my $records = $pluginObject->getJobDetailsRanged($runtimeParameters->{jobName}, $metadataValues->{buildNumber}, $lastNumber);
    logDebug("Records after GetRecordsAfter", Dumper $records);
    return $records;
}

sub getLastRecord {
    my ($self, $pluginObject) = @_;

    my $runtimeParameters = $pluginObject->newContext()->getRuntimeParameters();
    logDebug("Last record runtime params:", Dumper $runtimeParameters);
    my $lastNumber = $pluginObject->getLastBuildNumber($runtimeParameters->{jobName});
    my $jobDetails = $pluginObject->getJobDetails($runtimeParameters->{jobName}, $lastNumber);
    logDebug("Last job details: ", Dumper $jobDetails);
    return $jobDetails;
}

sub buildDataset {
    my ($self, $pluginObject, $records) = @_;

    my $dataset = $self->newDataset({
        reportObjectTypes => ['build'],
    });
    my $runtimeParameters = $pluginObject->newContext()->getRuntimeParameters();
    for my $row (@$records) {
        my $data = $dataset->newData({
            reportObjectType => 'build',
        });
        $row->{sourceUrl} = $row->{url};
        $row->{pluginConfiguration} = $runtimeParameters->{config};
        $row->{startTime} = $pluginObject->getDateFromJenkinsTimestamp($row->{timestamp});
        $row->{endTime} = $pluginObject->getDateFromJenkinsTimestamp($row->{timestamp} + $row->{duration});
        $row->{documentId} = $row->{url};
        $row->{buildStatus} = $row->{result};
        # hardcode
        $row->{launchedBy} = 'admin';
        for my $k (keys %$row) {
            next if ref $row->{$k};
            if ($k eq 'timestamp') {
                $row->{$k} = $pluginObject->getDateFromJenkinsTimestamp($row->{$k});
            }
            $data->{values}->{$k} = $row->{$k};
        }
        my $dataRef = $dataset->getData();
        unshift @$dataRef, $data;
    }
    return $dataset;
}

sub buildPayloadset {
    my ($self, $pluginObject, $dataset) = @_;

    my $payloadSet = $self->newPayloadset({
        reportObjectTypes => ['build'],
    });

    my $payloads = $payloadSet->getPayloads();
    my $data = $dataset->getData();
    for my $row (@$data) {
        my $values = $row->getValues();
        push @$payloads, $payloadSet->newPayload({
            values => $values,
            reportObjectType => 'build'
        });
    }

    return $payloadSet;
}

1;
