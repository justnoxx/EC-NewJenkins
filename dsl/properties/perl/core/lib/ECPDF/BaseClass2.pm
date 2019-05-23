package ECPDF::BaseClass2;
use strict;
use warnings;
use Data::Dumper;
use Carp;

sub defineClass {
    my ($class, $definitions) = @_;

    for my $k (keys %$definitions) {
        my $field = ucfirst $k;
        my $getter = "get$field";
        my $setter = "set$field";
        my $code = sprintf q|
        *{%s::%s} = sub {
            my ($self) = @_;
            return __get($self, $definitions, $k);
        };
        *{%s::%s} = sub {
            my ($self, $value) = @_;
            return __set($self, $definitions, $k, $value);
        };
|, $class, $getter, $class, $setter;
        # print "Code: $code\n";
        eval $code or do {
            croak "Error during method creation: $!\n";
        };
    }
    return 1;
}


sub __get {
    my ($self, $definitions, $field) = @_;
    if (defined $self->{$field}) {
        return $self->{$field};
    }
    return undef;
}

sub __set {
    my ($self, $definitions, $field, $value) = @_;

    if (ref $definitions->{$field}) {
        my $matcher = $definitions->{$field};
        if (!$matcher->match($value)) {
            # TODO: Improve this error message.
            if ($matcher->can('describe')) {
                my $msg = sprintf(
                    'Value for %s->{%s} should be: %s, but got: %s',
                    ref $self, $field, $matcher->describe(),
                    ref $value ? Dumper($value) : $value
                );
                croak $msg;
            }
            else {
                croak "Value for $self : $field should be a " . Dumper($matcher) . ", got: " . Dumper($value) . "\n";
            }
        }
    }
    else {
        print "[DEVWARNING] $field from " . ref $self . " does not have proper definition.\n";
    }
    $self->{$field} = $value;
    return $self;
}

sub new {
    my ($class, $opts) = @_;

    my $self = {};
    bless $self, $class;
    for my $k (keys %$opts) {
        my $setter = 'set' . ucfirst($k);
        my $getter = 'get' . ucfirst($k);

        if ($class->can($setter) && $class->can($getter)) {
            $self->$setter($opts->{$k});
        }
        else {
            croak "Field '$k' does not exist and was not defined\n";
        }
    }

    return $self;
}
1;
