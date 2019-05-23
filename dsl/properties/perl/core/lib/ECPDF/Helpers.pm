=head1 NAME

ECPDF::Helpers

=head1 AUTHOR

CloudBees

=head1 DESCRIPTION

This module provides various static helper functions.

To use them one should explicitly import them.

=head1 METHODS

=head2 trim

=head3 Usage

%%%LANG=perl%%%

    $str = trim(' hello world ');

%%%LANG%%%

=head2 isWin

=head3 Description

Returns true if we're running on windows system.

=head2 genRandomNumbers

=head3 Description

Generates random numbers.

=head2 bailOut

=head3 Description

Immediately aborts current execution and exits with exit code 1.

This exception can't be handled or catched.

=head3 Usage

%%%LANG=perl%%%

    bailOut("Something is very wrong");

%%%LANG%%%

=head2 inArray

=cut

package ECPDF::Helpers;
use base qw/Exporter/;

use strict;
use warnings;

our @EXPORT_OK = qw/
    trim
    isWin
    genRandomNumbers
    bailOut
    inArray
/;


sub trim {
    my (@params) = @_;

    @params = map {
        s/^\s+//gs;
        s/\s+$//gs;
        $_;
    } @params;

    return wantarray() ? @params : join '', @params;
}

sub isWin {
    if ($^O eq 'MSWin32') {
        return 1;
    }
    return 0;
}

sub genRandomNumbers {
    my ($mod) = @_;

    my $rand = rand($mod);
    $rand =~ s/\.//s;
    return $rand;
}

sub bailOut {
    my (@messages) = @_;

    my $message = join '', @messages;
    if ($message !~ m/\n$/) {
        $message .= "\n";
    }
    $message = "[BAILED OUT]: $message";
    print $message;
    exit 1;
}


sub inArray {
    my ($elem, @array) = @_;

    for my $e (@array) {
        return 1 if $elem eq $e;
    }

    return 0;
}


1;
