=head1 NAME

ECPDF::Component::CLI::ExecutionResult

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

This class represents a command-line execution result with exit code, stdout and stderr.

=head1 METHODS

=head2 getStdout()

=head3 Description

Returns STDOUT of executed command.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (String) STDOUT

=back

=head2 getStderr()

=head3 Description

Returns STDERR of executed command.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (String) STDERR

=back

=head2 getCode()

=head3 Description

Returns an exit code of executed command.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (String) Exit code.

=back

=cut

package ECPDF::Component::CLI::ExecutionResult;
use strict;
use warnings;
use base qw/ECPDF::BaseClass2/;
use ECPDF::Types;
__PACKAGE__->defineClass({
    stdout => ECPDF::Types::Scalar(),
    stderr => ECPDF::Types::Scalar(),
    code   => ECPDF::Types::Scalar(),
});
use Carp;


1;
