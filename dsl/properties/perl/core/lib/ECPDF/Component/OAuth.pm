=head1 NAME

ECPDF::Component::OAuth;

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A component to integrate with OAuth 1.0

=head1 INIT PARAMS

To read more about init params see L<ECPDF::ComponentManager>.

This component support following init params:

=over 4

=item (Required) base_url

=item (Required) oauth_consumer_key

=item (Required) oauth_signature_method

=item (Required) oauth_version

=item (Optional) oauth_nonce

=item (Optional) oauth_timestamp

=item (Optional) oauth_version

=item (Optional) request_method

=item (Optional) oauth_token

=item (Optional) oauth_verifier

=item (Optional) oauth_callback

=item (Optional) oauth_signature

=back


=head1 USAGE

%%%LANG=perl%%%

    my $rest = ECPDF::Client::REST->new({
        oauth => {
            private_key=> $privateKey,
            oauth_token => $token,
            oauth_consumer_key => $oauthConsumerKey,
            oauth_version => '1.0'
        }
    });
    my $jiraUrl = 'http://jira:8080';
    # rest client will automatically load ECPDF::Component::OAuth. You just need to get it.
    my $oauth = ECPDF::ComponentManager->getComponent('ECPDF::Component::OAuth');
    # create a hash reference request params, using oauth component
    my $requestParams = $oauth->augment_params_with_oauth('GET', $jiraUrl, {});
    # add these parameters to the request URL.
    $jiraUrl = $rest->augmentUrlWithParams($jiraUrl, $requestParams);
    # create request
    my $request = $rest->newRequest(GET => $jiraUrl);
    my $response = $rest->doRequest($request);

%%%LANG%%%

=over

=cut

package ECPDF::Component::OAuth;
use base qw/ECPDF::Component/;
use strict;
# use warnings;
use warnings FATAL => 'all';



use Data::Dumper;
use Carp;

use URI;
use URI::Escape qw/uri_escape/;
use MIME::Base64 qw/encode_base64/;

use LWP::UserAgent;
use HTTP::Request;
use JSON qw/encode_json/;

# TODO: implement dependencies system
use Bytes::Random::Secure::Tiny;

my @oauth_keys = qw/oauth_consumer_key oauth_nonce oauth_signature_method oauth_timestamp oauth_version request_method/;
my @optional_oauth_keys = qw/oauth_token oauth_verifier oauth_callback oauth_signature/;

=item B<new>

=cut

sub init {
    my ($class, $params) = @_;

    return $class->new($params);
}


sub new {
    my ($class, $oauth_params) = @_;

    # Checking mandatory fields
    for my $cfg_param (qw/base_url oauth_consumer_key oauth_version oauth_signature_method/){
        croak "Missing mandatory OAuth parameter '$cfg_param'.\n" unless $oauth_params->{$cfg_param};
    }

    if ($oauth_params->{oauth_signature_method} eq 'RSA-SHA1' && !$oauth_params->{private_key}){
        croak "Missing mandatory OAuth parameter 'private_key'.\n";
    }

    my $self = { %$oauth_params };

    # Initializing secure random generator
    $self->{rng} = Bytes::Random::Secure::Tiny->new;

    return bless($self, $class);
}


=item B<request>

=cut
sub request {
    my ( $self, $method, $url, $request_params ) = @_;

    my $query_params = $self->augment_params_with_oauth($method, $url, $request_params);

    my URI $url_with_oauth = URI->new($url);

    if ('GET' eq $method) {
        $url_with_oauth->query_form($query_params);
    }

    my HTTP::Request $req = HTTP::Request->new($method, $url_with_oauth);

    if ($method =~ m/POST|PUT|DELETE|OPTIONS/si) {
        # Extract oauth params
        my %oauth_params = ();
        my @oauth_params = (@oauth_keys, @optional_oauth_keys);

        for my $p (@oauth_params){
            if (exists $query_params->{$p}){
                $oauth_params{$p} = $query_params->{$p};
                delete $query_params->{$p};
            }
        }

        # $req->header('Authorization', "Bearer "
        #     . join(",\n", map {_encode($_). "=" . _encode($oauth_params{$_})} keys %oauth_params));

        $req->uri->query_form(\%oauth_params);

        $req->header('Content-Type', 'application/json');
        $req->content(encode_json($query_params));
    }

    my $ua = $self->ua();
    my HTTP::Response $res = $ua->request($req);

    # All OAuth problems are returned in WWW-Authenticate header or response body
    if (my @auth_headers = $res->header('www-authenticate')) {
        for my $auth_response (@auth_headers) {
            $auth_response =~ /oauth_problem="([a-z_]+)",?/ if $auth_response;
            die "OAUTH PROBLEM: " . $1 . "\n" if $1;
        }
    }

    my $content = $res->decoded_content();
    die 'No content in response' if ! $content;

    return $content;
}

=item B<augment_params_with_oauth>

=cut
sub augment_params_with_oauth {
    my ( $self, $method, $url, $request_params ) = @_;

    # Clear URL
    $url =~ s/\?.*$//;

    my %params = ( %{$request_params ? $request_params : {}} );

    $self->renew_nonce();

    # Adding optional keys
    # "oauth_token" not exists on first request
    # "oauth_verifier" and "oauth_callback" are used only in OAuth 1.0a version
    for my $optional_key (@optional_oauth_keys) {
        next unless $self->{$optional_key};
        push @oauth_keys, $optional_key;
    }

    # OAuth params are stored in self
    foreach my $oauth_k (@oauth_keys) {
        croak "Missing OAuth parameter $oauth_k" unless $self->{$oauth_k};
        $params{$oauth_k} = $self->{$oauth_k};
    }

    # Calculate signature
    my $sign = $self->calculate_the_signature($url, $method, %params);

    # Prepare your content
    my %request_params = (
        %params,
        oauth_signature => MIME::Base64::encode_base64($sign, ''),
    );

    # Form request parameters from given params hash
    for my $k (keys %params) {
        croak "Missing value for $k" unless defined $params{$k};
        $request_params{$k} = uri_escape($params{$k});
    }

    return \%request_params;
}

=item B<calculate_the_signature>

Collect all parameters for signature string:
  - Request method
  - Request path
  - All parameters that will be in query (collect and encode all at once)

=cut
sub calculate_the_signature {
    my ( $self, $url, $method, %request_params ) = @_;

    my @params_for_signature = ();
    if ($method eq 'GET'){
        # All parameters will be used for a signature
        for my $k (sort keys %request_params) {
            push(@params_for_signature, "$k=$request_params{$k}");
        }
    }
    elsif ($method =~ m/POST|PUT|DELETE|OPTIONS/si) {
        # In POST method only oauth parameters are collected to base signature string
        my %oauth_lookup = map { $_ => 1 } (@oauth_keys, @optional_oauth_keys);
        for my $k (sort keys %request_params) {
            if ($oauth_lookup{$k}){
                push(@params_for_signature, "$k=$request_params{$k}") ;
            }
        }
    }
    else {
        croak "Unsupported method $method";
    }

    my @sign_parameters = ();
    push(@sign_parameters, $method);
    push(@sign_parameters, _encode($url));
    push(@sign_parameters, _encode(join('&', @params_for_signature))) if (@params_for_signature);

    my $sign_base_string = join('&', @sign_parameters);

    if ('RSA-SHA1' eq $self->{oauth_signature_method}) {
        croak("Private key is missing") unless $self->{private_key};

        # Require only if not already imported
        # Should be loaded from property (due to newer Math::BigInt)
        if (!$Crypt::Perl::RSA::Parse::VERSION) {
            # Forcing Math::BigInt libraries to be loaded from property
            $INC{'Math/BigInt'} = $INC[$#INC];
            $INC{'Math/BigInt/Calc'} = $INC[$#INC];
            $INC{'Math/BigInt/Pari'} = $INC[$#INC];

            # require EC::OAuthDependencies::RSA;
            require ECPDF::Service::RSA;

            Crypt::Perl::RSA::Parse->import();
            Crypt::Perl::RSA::PrivateKey->import();
        }

        my $prv_key = Crypt::Perl::RSA::Parse::private($self->{private_key});
        my $sign = $prv_key->sign_RS1($sign_base_string);

        die "Signature length incorrect \n" unless (length $sign == 128);

        return $sign;
    }
    if ('HMAC-SHA1' eq $self->{oauth_signature_method}) {
        my $secret = $self->{oauth_secret};
        require Digest::SHA;
        Digest::SHA->import(qw/hmac_sha1/);

        croak 'Not sure about params for hmac_sha1';
        return Digest::SHA::hmac_sha1($secret . '&' . $sign_base_string);
    }

    die "Unknown signature method: $self->{oauth_signature_method}. Supported: RSA-SHA1, HMAC-SHA1\n";
}

=item B<parse_token_response>

=cut
sub parse_token_response {
    my ( $self, $content ) = @_;

    my $resp = _parse_url_encoded($content);

    if ($resp->{oauth_problem}) {
        print "OAuth problem: $resp->{oauth_problem}";
        return undef;
    }

    if ($self->{oauth_token_secret} && $self->{oauth_token_secret} ne $resp->{oauth_token_secret}) {
        croak "Someone has tampered request. OAuth token secrets not are equal"
    }

    $self->{oauth_token} = $resp->{oauth_token};
    $self->{oauth_token_secret} = $resp->{oauth_token_secret};

    return( $resp->{oauth_token}, $resp->{oauth_token_secret} );
}

=item B<request_token>

=cut
sub request_token {
    my ( $self ) = @_;
    my $response = $self->request($self->{request_method}, $self->{base_url} . $self->{request_token_path});
    $self->parse_token_response($response);
}

=item B<authorize_token>

=cut
sub authorize_token {
    my ( $self ) = @_;
    my $response = $self->request($self->{request_method}, $self->{base_url} . $self->{access_token_path});
    $self->parse_token_response($response);
}

=item B<generate_auth_url>

=cut
sub generate_auth_url {
    my ( $self, $token, %extra_params ) = @_;

    $token ||= $self->{oauth_token};

    die 'No request token' unless $token;

    my $oauth_url = URI->new($self->{base_url} . $self->{authorize_token_path});
    $oauth_url->query_form({
        oauth_token => $token,
        %{( %extra_params ) ? \%extra_params : {}}
    });

    return $oauth_url;
}

=item B<renew_nonce>

=cut
sub renew_nonce {
    my ( $self ) = @_;

    my $ts = time();

    $self->{oauth_timestamp} = $ts;
    $self->{oauth_nonce} = $ts . $self->{rng}->irand();
}

=item B<_encode>

=cut
sub _encode {
    my ( $str ) = @_;
    return URI::Escape::uri_escape_utf8($str, '^\w.~-')
}

=item B<_parse_url_encoded>

=cut
sub _parse_url_encoded {
    my ( $query ) = @_;
    return unless $query;

    # Parse query
    my %query_params = ();
    my @pairs = split('&', $query);

    foreach my $pair (@pairs) {
        next unless $pair;
        my ( $k, $v ) = split('=', $pair);
        next unless $k;
        $query_params{$k} = $v || '';
    }

    return \%query_params;
}

=item B<ua>

=cut
sub ua {
    my ( $self, $value ) = @_;

    if (defined $value) {
        $self->{_ua} = $value;
        return 1;
    }

    if (! $self->{_ua}) {
        $self->{_ua} = LWP::UserAgent->new();
    }

    return $self->{_ua};
}

=back

=cut

1;
