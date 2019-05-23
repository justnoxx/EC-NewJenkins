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

    my $runtimeParameters = $pluginObject->getContext()->getRuntimeParameters();
    logDebug("Initial Get Records runtime parameters:", Dumper $runtimeParameters);
    my $lastNumber = $pluginObject->getLastBuildNumber($runtimeParameters->{jobName});
    logDebug("Initial Get Records last build number: $lastNumber");
    my $records = $pluginObject->getJobDetailsRanged($runtimeParameters->{jobName}, 0, $lastNumber, $limit);
    return $records;
}


sub getRecordsAfter {
    my ($self, $pluginObject, $metadata) = @_;

    my $runtimeParameters = $pluginObject->getContext()->getRuntimeParameters();
    my $lastNumber = $pluginObject->getLastBuildNumber($runtimeParameters->{jobName});
    my $metadataValues = $metadata->getValue();
    logDebug("Got metadata value in getRecordsAfter:", Dumper $metadataValues);
    my $records = $pluginObject->getJobDetailsRanged($runtimeParameters->{jobName}, $metadataValues->{buildNumber}, $lastNumber);
    logDebug("Records after GetRecordsAfter", Dumper $records);
    return $records;
}

sub getLastRecord {
    my ($self, $pluginObject) = @_;

    my $runtimeParameters = $pluginObject->getContext()->getRuntimeParameters();
    logDebug("Last record runtime params:", Dumper $runtimeParameters);
    my $lastNumber = $pluginObject->getLastBuildNumber($runtimeParameters->{jobName});
    my $jobDetails = $pluginObject->getJobDetails($runtimeParameters->{jobName}, $lastNumber);
    logDebug("Last job details: ", Dumper $jobDetails);
    return $jobDetails;
}

sub buildDataset {
    my ($self, $pluginObject, $records) = @_;

    my $dataset = $self->newDataset(['build']);
    my $runtimeParameters = $pluginObject->getContext()->getRuntimeParameters();
    @$records = reverse @$records;
    for my $row (@$records) {
        my $data = $dataset->newData({
            reportObjectType => 'build',
        });
        print "Retrieved data ref: $data\n";
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
            $data->addValue($k => $row->{$k});
            # $data->{values}->{$k} = $row->{$k};
        }

        if ($runtimeParameters->{retrieveTestResults}) {
            logInfo("Test results retrieval is enabled");
            my $testReport = $pluginObject->getTestReport(
                $runtimeParameters->{jobName},
                $row->{number},
                $runtimeParameters->{testReportUrl}
            );
            if (%$testReport) {
                logInfo("Got testreport for build number $row->{number}, creating new dependent data");
                my $dependentData = $data->createNewDependentData('quality');

                logDebug("Test Report: ", $testReport);
                $dependentData->addValue(projectName => $row->{projectName});
                $dependentData->addValue(releaseName => $row->{releaseName});
                $dependentData->addValue(releaseProjectName => $row->{releaseProjectName});
                $dependentData->addValue(skippedTests => $testReport->{skipCount}    || 0);
                $dependentData->addValue(successfulTests => $testReport->{passCount} || 0);
                $dependentData->addValue(failedTests => $testReport->{failCount}     || 0);
                $dependentData->addValue(timestamp => $row->{endTime});

                $dependentData->addValue(category => $runtimeParameters->{testCategory});
                $dependentData->addValue(
                    totalTests => $testReport->{skipCount} + $testReport->{skipCount} + $testReport->{skipCount}
                );
            }
        }
        # my $dataRef = $dataset->getData();
        # unshift @$dataRef, $data;
    }
    return $dataset;
}

# sub buildPayloadset {
#     my ($self, $pluginObject, $dataset) = @_;

#     my $payloadSet = $self->newPayloadset({
#         reportObjectTypes => ['build'],
#     });

#     # my $payloads = $payloadSet->getPayloads();
#     my $data = $dataset->getData();
#     for my $row (@$data) {
#         my $values = $row->getValues();
#         my $pl = $payloadSet->newPayload({
#             values => $values,
#             reportObjectType => 'build'
#         });
#     }

#     return $payloadSet;
# }

1;
