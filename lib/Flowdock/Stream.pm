package Flowdock::Stream;

use Moose;
use Carp;
use Moose::Util::TypeConstraints;
use LWP::UserAgent;
use JSON::XS;
use Email::Valid;
use namespace::autoclean;

=head1 NAME

Flowdock::Stream - Interface to the Flowdock Streaming API

=cut

subtype 'Email'
    => as 'Str'
    => where { Email::Valid->address($_) }
    => message { "$_ is not a valid email address" };

has username => (
	is => 'ro',
	isa => 'Email');

has password => (
	is => 'ro',
	isa => 'Str');

has personal_token => (
	is => 'ro',
	isa => 'Str');

has org => (
	is => 'ro',
	isa => 'Str',
	required => 1);

has base_url => (
	is => 'rw',
	isa => 'Str'
);

=head1 METHODS

=head2 BUILD

Builds like Flowdock::REST

=cut

sub BUILD {
	my $self = shift;
	if ($self->username()) {
		$self->password() or croak "If supplying a username, must have a password.";
		$self->base_url("https://".$self->username().":".$self->password()."\@stream.flowdock.com/flows/".$self->org());
	} elsif ($self->personal_token()) {
		$self->base_url("https://".$self->personal_token()."\@stream.flowdock.com/flows/");
	} else { croak "You must supply either username/password or a personal token"; }
}

=head2 stream_flow

Gets a particular flow.

Required: flow, function

You must provide a function for the callback handler. The handler needs to return a true value to continue being used.

=cut

sub stream_flow {
	my ($self, $flow, $function) = @_;
	$flow or croak "Did you forget to provide flows?";
	$function or croak "You must provide get_flows with a function (e.g. \$foo = sub {}) that returns true for the callback";
	my $url = $self->get_single_flow_url($flow);
	my $stream = $self->stream_action_get($url, $function);
}

=head2 stream_flows

Gets as many flows as you want, passed as an array.

Required: flows, function

=cut

sub stream_flows {
	my ($self, $flows, $function) = @_;
	$flows or croak "Did you forget to provide flows?";
	$function or croak "You must provide get_flows with a function (e.g. \$foo = sub {}) that returns true for the callback";
	my $url = $self->get_multiple_flows_url($flows);
	my $stream = $self->stream_action_get($url, $function);
}

=head2 stream_action_get

Undertakes the getting and setting up the callback handler for the stream.

=cut

sub stream_action_get {
	my ($self, $url, $function) = @_;
	my $client = LWP::UserAgent->new;
	my $process = sub { my($request, $ua, $h, $data) = @_; &$function(JSON::XS->new->incr_parse($data));};
	$client->add_handler( response_data => $process);
	my $response = $client->get($url);
	return $response;
}

=head2 get_single_flow_url

Constructs the URL for a single flow

=cut

sub get_single_flow_url {
	my ($self, @url_parts) = @_;
	my $url = $self->base_url()."/$self->org()";
	for my $part (@url_parts) {
		$url.="/$part";
	}
	return $url;
}

=head2 get_multiple_flows_url

Constructs the URL for multiple flows

=cut

sub get_multiple_flows_url {
	my ($self, $url_parts) = @_;
	my $url = $self->base_url()."?filter=";
	foreach (@$url_parts) { $_=$self->org()."/".$_ }
	$url.=join(",", @$url_parts);
	return $url;
}

__PACKAGE__->meta->make_immutable;

1;
