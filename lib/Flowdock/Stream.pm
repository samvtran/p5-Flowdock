package Flowdock::Stream;
use strict;
use warnings;
use Moo;
use Carp;
use JSON;
use Email::Valid;
use MIME::Base64;
use URI::Encode qw/uri_encode/;

use AnyEvent;
use AnyEvent::HTTP;

use namespace::autoclean;

=head1 NAME

Flowdock::Stream - Interface to the Flowdock Streaming API

=cut

has username => (
	is => 'ro',
	isa => sub {
		croak "$_[0] is not a valid email address" unless Email::Valid->address($_[0]);
	});

has password => (
	is => 'ro');

has personal_token => (
	is => 'ro');

has org => (
	is => 'ro');

has base_url => (
	is => 'rw',
	# default => sub { return '/flows'; });
	default => sub { return 'https://stream.flowdock.com/flows'; });

has basic_auth => (
	is => 'rw');

=head1 METHODS

=head2 new

my $stream = Flowdock::Stream->new(%options)

Starts a Flowdock::Stream stream

Required: username/password or personal_token, org

=cut

sub BUILD {
	my $self = shift;
	if ($self->username()) {
		$self->password() or croak "If supplying a username, must have a password.";
		$self->basic_auth('Basic '.encode_base64($self->username.":".$self->password, q{}));
	} elsif ($self->personal_token()) {
		$self->basic_auth('Basic '.encode_base64($self->personal_token, q{}));
	} else { croak "You must supply either username/password or a personal token"; }
	$self->org() or croak "Must have an organization set!";
}

=head2 stream_flows

$stream->stream_flows(
	flows => \@flows|$flows,
	on_(error|event|keepalive|disconnect) => &callback
);

Gets as many flows as you want, passed as an array.

Required: flows (array of names||name of a single flow)

A callback can be provided to actually make this module useful.
on_error: Will send a string representing the error status and reason. Default error handler is already provided using croak.
on_event: Receives body and headers respectively. For capturing useful events.
on_keepalive: Flowdock sends \n periodically as a keepalive. You can make sure that
happens here.
on_disconnect: Runs when the connection closes for whatever reason.

=cut

sub stream_flows {
	my $self = shift;
	my %args = @_;
	my $flows = $args{flows};
	my $on_event = $args{on_event} || sub {};
	my $on_keepalive = $args{on_keepalive} || sub {};
	my $on_error = $args{on_error} || sub { croak @_ };
	my $on_disconnect = $args{on_disconnect} || sub {};
	$flows or croak "Did you forget to provide flows?";

	my $url = $self->_get_api_url($flows);
	print $url;
	my ($response, $header, $body);
	http_request(
		GET => $url,
		headers =>  { Authorization => $self->basic_auth },
		timeout => 5000,
		on_body => sub {
			my ($body, $header) = @_;
			unless($body !~ /^\n$/) { return $on_keepalive->(); }
			unless($header->{Status} =~ /^2/) {
				$on_error->("ERROR: $header->{Status} $header->{Reason}\n");
			}
			$on_event->(decode_json $body, $header);
		},
		sub { $on_disconnect->(); }
	);
}

=head2 _get_api_url

Constructs the URL for multiple flows

=cut

sub _get_api_url {
	my ($self, $url_parts) = @_;
	my $url = $self->base_url()."?filter=";
	if(ref($url_parts) eq 'ARRAY') {
		@$url_parts = map { $self->org()."/".$_ } @$url_parts;
		$url.=uri_encode(join(",", @$url_parts));
	}
	else {
		$url.= $self->org()."/".uri_encode($url_parts);
	}
	return $url;
}

__PACKAGE__->meta->make_immutable;

1;
