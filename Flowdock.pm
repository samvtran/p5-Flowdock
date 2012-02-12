package Flowdock;
use strict;
use warnings;

use Carp;
use Moose;
use LWP::UserAgent;
use namespace::autoclean;

# Instead of using required, we're using the croaks in BUILD for custom error messages.
# There's a better way to do this for sure.
# TODO: POD
has api_token => (
	is => 'ro',
	isa => 'Str');

has source => (
	is => 'ro',
	isa => 'Str');

has project => (
	is => 'ro',
	required => 0,
	isa => 'Str');

has from => (
	is => 'ro',
	isa => 'HashRef');

my $flowdock_api_url = "https://api.flowdock.com/v1/messages/influx";

sub BUILD {
	my $self = shift;
	$self->api_token()
	    or croak "Flow must have api_token attribute";
	$self->source() && $self->source() =~ /^[0-9a-z_]+$/i
	    or croak "Flow must have valid source attribute, only alphanumeric characters and underscores can be used";
	if ($self->project() && $self->project() !~ /^[0-9a-z_ ]+$/i) {
		croak "Optional attribute project can only contain alphanumeric characters and underscores"; }

}

sub send_message {
	my ($self, @messages) = @_;
	for my $message (@messages){
		$message->{content} && $message->{subject} or croak "Message must have both subject and content";
		$self->from()->{address} or croak "The flow's from attribute is missing the address attribute";

		# Parameters to include in the POST
		my %params = (
			source => $self->source(),
			format => 'html', #The only format supported for now
			from_address => $self->from()->{address},
			subject => $message->{subject},
			content => $message->{content});
		# Optional parameters
		$params{from_name} = $self->from()->{name} if $self->from()->{name};
		$params{project} = $self->project() if $self->project();
		$params{link} = $message->{link} if $message->{link};

		# Tags take a little more work
		# First make sure they're in an array, then join, then add them if they even exist. Oy vey.
		my $tags;
		if ($message->{tags} && ref($message->{tags}) ne 'ARRAY') { croak "Tags must be in an array; e.g. ['foo', 'bar']"; }
		if ($message->{tags} && scalar(@{$message->{tags}}) > 0) { $tags = join(",",@{$message->{tags}}); }
		$params{tags} = $tags if $tags;

		my $ua = LWP::UserAgent->new;
		my $response = $ua->post( get_flowdock_api_url($self), Content => \%params);
		if ($response->is_success) {
			print "Success! Your message has been sent to Flowdock.\n";
		} else {
			die $response->status_line;
		}
	}
}


sub get_flowdock_api_url {
	my $self = shift;
	return "$flowdock_api_url/".$self->api_token();
}

__PACKAGE__->meta->make_immutable;

1;
