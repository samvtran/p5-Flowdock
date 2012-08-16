package Flowdock::Stream;
use strict;
use warnings;
use Moo;
use Carp;
use Net::Curl::Easy qw/:constants/;
use Email::Valid;
use MIME::Base64;
use URI::Encode qw/uri_encode/;
use JSON::XS;
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
	default => sub { return '/flows'; });

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
		#$self->basic_auth('Basic '.encode_base64($self->username.":".$self->password, q{}));
		$self->base_url('https://'.$self->username.":".$self->password.'@stream.flowdock.com/flows');
	} elsif ($self->personal_token()) {
		#$self->basic_auth('Basic '.encode_base64($self->personal_token, q{}));
		$self->base_url('https://'.$self->personal_token().'@stream.flowdock.com/flows');
	} else { croak "You must supply either username/password or a personal token"; }
	$self->org() or croak "Must have an organization set!";
}

=head2 stream_flow

$stream->stream_flow($flow, &callback)

Gets a particular flow.

Required: flow, function

You must provide a function for the callback handler.
The callback receives a hashref of JSON decoded data.

=cut

sub stream_flow {
	my ($self, $flow, $function) = @_;
	$flow or croak "Did you forget to provide flows?";
	$function or croak "You must provide get_flows with a function (e.g. \$foo = sub {}) that returns true for the callback";
	my $url = $self->_get_api_url($flow);
	my $stream = $self->_get($url, $function);
}

=head2 stream_flows

$stream->stream_flows(\@flows, &callback);

Gets as many flows as you want, passed as an array.

Required: flows (array of names), function
You must provide a function for the callback handler.
The callback receives a hashref of JSON decoded data.

=cut

sub stream_flows {
	my ($self, $flows, $function) = @_;
	$flows or croak "Did you forget to provide flows?";
	$function or croak "You must provide get_flows with a function (e.g. \$foo = sub {}) that returns true for the callback";
	my $url = $self->_get_api_url($flows);
	my $stream = $self->_get($url, $function);
}

=head2 _get

Undertakes the getting and setting up the callback handler for the stream.

=cut

sub _get {
	my ($self, $url, $function) = @_;
	#print "Using $url\n";
	my $client = Net::Curl::Easy->new();
	my $header = [
		"Connection: keep-alive",
		"Accept: application/json"
	];
	my $test_cb = sub {
		my ($easy, $data, $uservar) = @_;
		#print "Processing\n";
		my $new_data = $data;
		if($data && $data !~ m/^\n$/i) {
			# Returns decoded data to function
			$function->(decode_json $data);
		}
		return length $data;
	};
	$client->setopt(CURLOPT_HTTPHEADER, $header);
	$client->setopt(CURLOPT_CONNECTTIMEOUT, 0);
	$client->setopt(CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
	$client->setopt(CURLOPT_URL, $url);
	$client->setopt(CURLOPT_WRITEFUNCTION, $test_cb);
	$client->perform();
}

=head2 _get_api_url

Constructs the URL for multiple flows

=cut

sub _get_api_url {
	my ($self, $url_parts) = @_;
	my $url = $self->base_url()."?filter=";
	if(ref($url_parts) eq 'ARRAY') {
		foreach (@$url_parts) { $_=$self->org()."/".$_ }
		$url.=join(",", @$url_parts);
	}
	else {
		$url.= $self->org()."/".$url_parts;
	}
	return $url;
}

__PACKAGE__->meta->make_immutable;

1;
