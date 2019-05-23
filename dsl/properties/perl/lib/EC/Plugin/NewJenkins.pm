package EC::Plugin::NewJenkins;
use strict;
use warnings;
use base qw/ECPDF/;
use Data::Dumper;
use ECPDF::Log;
use ECPDF::ComponentManager;
use ECPDF::Helpers qw/bailOut/;
# use EC::Plugin::NewJenkins::Reporting;
use Carp;
use JSON;
# Feel free to use new libraries here, e.g. use File::Temp;

# Service function that is being used to set some metadata for a plugin.
sub pluginInfo {
    return {
        pluginName    => '@PLUGIN_KEY@',
        pluginVersion => '@PLUGIN_VERSION@',
        configFields  => ['config'],
        configLocations => ['ec_plugin_cfgs']
    };
}


# Auto-generated method for the procedure CollectReportingData/CollectReportingData
# Add your code into this method and it will be called when step runs
sub collectReportingData {
    my ($pluginObject, $params, $stepResult) = @_;
    my $context = $pluginObject->getContext();

    $stepResult->setOutcomeProperty('/myJob/property', 1);
    $stepResult->apply();
    exit 0;
    $ECPDF::Log::LOG_LEVEL = 2;
    # testing test results

    # my $testResult = $pluginObject->getTestReport('JPetStore', '2', '/testReport');
    # print Dumper $testResult;
    # end of testing test results

    # my $params = $context->getRuntimeParameters();

    my $reporting = ECPDF::ComponentManager->loadComponent('EC::Plugin::NewJenkins::Reporting', {
        reportObjectTypes => ['build'],
        metadataUniqueKey => $params->{jobName},
        payloadKeys       => ['buildNumber']
    }, $pluginObject);
    logDebug "Ref of reporting: ", ref $reporting;
    $reporting->CollectReportingData();
}


## === step ends ===
# Please do not remove the marker above, it is used to place new procedures into this file.



### plugin subroutines.

sub doRestRequest {
    my ($self, $method, $url, $params) = @_;

    my $context = $self->getContext();
    my $rp = $context->getRuntimeParameters();
    print "RP:", Dumper $rp;
    my $rest = $context->newRESTClient();


    my $jenkinsUrl = $rp->{endpoint};
    $jenkinsUrl =~ s|\/$||s;
    $jenkinsUrl .= $url;
    my $request = $rest->newRequest($method, $jenkinsUrl);
    $request->authorization_basic($rp->{user}, $rp->{password});

    $request->header('accept' => 'application/json');
    $request->header('content-type' => 'application/json');

    print "Request:", Dumper $request;
    return $rest->doRequest($request);
}

sub getJobDetails {
    my ($self, $jobName, $buildNumber) = @_;

    my $url;
    if (!$buildNumber) {
        $url = sprintf('/job/%s/api/json?depth=2', $jobName);
    }
    else {
        $url = sprintf('/job/%s/%s/api/json?depth=2', $jobName, $buildNumber);
    }
    my $response = $self->doRestRequest(GET => $url);

    if (!$response->is_success()) {
        bailOut("Failed to get job details: ", Dumper $response);
    }
    return decode_json($response->decoded_content());
}

sub getJobDetailsRanged {
    my ($self, $job_name, $start_number, $end_number, $builds_count) = @_;

    if (!defined $builds_count) {
        logDebug("Builds count is undefined, setting to 10");
        if ($start_number > 0) {
            $builds_count = $end_number - $start_number;
        }
        else {
            $builds_count = 10;
        }
    }
    logInfo("Job name: $job_name\nStart number: $start_number\nEnd number: $end_number\nBuilds count: $builds_count");
    if (!$job_name) {
        croak "Missing job_name";
    }
    if (!defined $start_number) {
        croak "Missing start_number";
    }
    my $result = [];
    my $url = "/job/$job_name/api/json?depth=3&tree=allBuilds[*]";
    # end number is 6, last build is 5, so, it will be 0,1.
    # $end_number =
    my ($sn, $en) = (0, $end_number - $start_number);
    my $ranges = $self->build_ranges($sn, $en, $builds_count);
    logDebug("Ranges built: ", $ranges);
    for my $range (@$ranges) {
        my $new_url = $url . $range;
        my $response = $self->doRestRequest(GET => $new_url);
        # my $response = $self->request(GET => $self->getBaseUrl($new_url));
        if ($response =~ m/^Error:\s*?404/) {
            bailOut(sprintf 'Jenkins job %s does not exist', $job_name);
        }
        $response = decode_json($response->decoded_content());
        # print Dumper $response;
        for my $bld (@{$response->{allBuilds}}) {
            push @$result, $bld;
        }
    }
    return $result;
}

sub build_ranges {
    my ($self, $start_from, $end_at, $total_builds) = @_;

    logInfo "Start from: $start_from, end at: $end_at, total: $total_builds\n";
    if ($total_builds) {
        $end_at = $start_from + $total_builds;
    }
    my $done = 0;
    my ($s, $e);
    $s = $start_from;
    my $ranges = [];
    while (!$done) {
        $e = $s + 50;
        my $t = $s;
        push @$ranges, "{$t,$e}";
        if ($e >= $end_at) {
            $done = 1;
            $ranges->[-1] = "{$t,$end_at}";
        }
        $s += 50;
    }
    return $ranges;
}


sub getLastBuildNumber {
    my ($self, $jobName) = @_;

    if (!$jobName) {
        bailOut("JobName is a mandatory parameter for getLastBuildNumber");
    }
    my $object = $self->getJobDetails($jobName);
    my $retval;
    if (exists $object->{lastBuild}) {
        if ($object->{lastBuild}->{number}) {
            $retval = $object->{lastBuild}->{number};
        }
        else {
            $retval = 0;
        }
    }
    else {
        $self->bail_out("Last build information is not available.");
    }
    return $retval;

}

sub getTestReport {
    my ($self, $jobName, $buildNumber, $testReportUrl) = @_;

    my $path = "/job/$jobName/$buildNumber";
    $testReportUrl ||= '/testReport';
    $path .= $testReportUrl;
    $path .= '/api/json?depth=2';
    my $response;
    my $retval = {};
    eval {
        $response = $self->doRestRequest(GET => $path);
        $response = $response->decoded_content();
        if ($response =~ m/^Error:\s*?404/) {
            logInfo(sprintf 'Test report is not available at %s', $testReportUrl);
            return {};
        }
        $retval = decode_json($response);
        1;
    };
    if (%$retval) {
        # TODO: Improve and add getBaseUrl
        $retval->{url} = $path;
    }

    return $retval;
}



sub getDateFromJenkinsTimestamp {
    my ($self, $timestamp) = @_;

    $timestamp =~ m/(\d{3})$/;
    my $ms = $1;
    $timestamp =~ s/\d{3}$//gs;
    my ($S, $M, $H, $d, $m, $Y) = gmtime($timestamp);
    $m += 1;
    $Y += 1900;
    # 2017-05-28T23:34:56Z"
    my $dt = sprintf('%04d-%02d-%02dT%02d:%02d:%02d', $Y,$m, $d, $H, $M, $S);
    $dt .= 'Z';
    return $dt;
}

1;
