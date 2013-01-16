# ABSTRACT: Unregister packages from a stack

package Pinto::Action::Pop;

use Moose;
use MooseX::Types::Moose qw(Bool);

use Pinto::Exception qw(throw);
use Pinto::Types qw(DistSpecList StackName StackDefault StackObject);

use namespace::autoclean;

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

extends qw( Pinto::Action );

#------------------------------------------------------------------------------

with qw( Pinto::Role::Committable );

#------------------------------------------------------------------------------

has targets   => (
    isa      => DistSpecList,
    traits   => [ qw(Array) ],
    handles  => {targets => 'elements'},
    required => 1,
    coerce   => 1,
);


has stack => (
    is        => 'ro',
    isa       => StackName | StackDefault | StackObject,
    default   => undef,
);


has force => (
    is        => 'ro',
    isa       => Bool,
    default   => 0,
);

#------------------------------------------------------------------------------


sub execute {
    my ($self) = @_;

    my $stack = $self->repo->get_stack($self->stack)->open;
    $self->_pop($_, $stack) for $self->targets;
    return $self->result if $self->dryrun or $stack->has_not_changed;

    my $message = $self->edit_message(stacks => [$stack]);
    $stack->close(message => $message);
    return $self->result->changed;
}

#------------------------------------------------------------------------------

sub _pop {
    my ($self, $target, $stack) = @_;

    my $dist  = $self->repo->get_distribution(spec => $target);
    throw "Distribution $target is not in the repository" if not defined $dist;

    my $did_unregister = $dist->unregister(stack => $stack, force => $self->force);

    $self->result->changed if $did_unregister;

    return;
}

#------------------------------------------------------------------------------

sub message_title {
    my ($self) = @_;

    my $targets  = join ' ', $self->targets;
    my $force    = $self->force ? ' with force' : '';

    return "Popped$force $targets.";
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------

1;

__END__
