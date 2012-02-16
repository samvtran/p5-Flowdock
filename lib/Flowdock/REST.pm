package Flowdock::REST;
use Carp;
use Moose;
use Moose::Util::TypeConstraints;
use REST::Client;
use JSON::XS;
use Email::Valid;
use namespace::autoclean;

=head1 NAME

Flowdock::REST - An interface to Flowdock's REST API

=head1 TODO

Refactor the way tags are set since we use this in the Push API too.
Refactor the Team Inbox code so that the REST and Push APIs use the same code
Refactor the messages overall so we can just change event to match what's being sent,
but the Team Inbox stuff needs to be refactored first.
Figure out the best way to even populate the Team Inbox stuff from here. Probably add ways to do it from the REST object too.
Add user parameter to list_flows

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

has flow => (
	is => 'rw',
	isa => 'Str');

has messages => (
	is => 'ro',
	isa => 'ArrayRef');

my $base_url;

=head1 METHODS

=head2 BUILD

Constructs the REST object.

Required: username/password OR personal_token
Optional: org, flow, messages
NOTE: flow will be used for get_flow if flow isn't passed to it explicitly.

=cut

sub BUILD {
	my $self = shift;
	if ($self->username()) {
		$self->password() or croak "If supplying a username, must have a password.";
		$base_url = "https://".$self->username().":".$self->password()."\@api.flowdock.com/v1/flows";
	} elsif ($self->personal_token()) {
		$base_url = "https://".$self->personal_token()."\@api.flowdock.com/v1/flows";
	} else { croak "You must supply either username/password or a personal token"; }
}

=head2 list_flows

Lists all flows for a user.

Optional: users
NOTE: toggling users is not working at the moment

=cut

sub list_flows { #Not sure toggling users actually works right now
	my ($self) = @_;
	my $response = $self->rest_action_get($base_url);
	return $response;
}

=head2 get_flow

Gets a particular flow's information

Optional: flow
NOTE: By leaving flow out, you must have flow from the base Flowdock::REST object set

=cut

sub get_flow {
	my ($self, $flow) = @_;
	my $url;
	if ($self->{flow}) { $url = $self->get_flowdock_api_url($self->{org}, $self->{flow}); }
	elsif ($flow) { $url = $self->get_flowdock_api_url($self->{org}, $flow); }
	else { croak "You must provide flow through the Flowdock::REST object or when using get_flow()"; }
	return $self->rest_action_get($url);
}

=head2 send_message

Sends a message to the inbox or chat or sets the status of the user

=cut

sub send_message {
	my ($self, @messages) = @_;
	my $url;
	for my $message (@messages) {
		if ($self->{flow}) { $url = $self->get_flowdock_api_url($self->{org}, $self->{flow}, 'messages'); }
		elsif ($message->{flow}) { $url = $self->get_flowdock_api_url($self->{org}, $message->{flow}, 'messages'); }
		else { croak "You must specify a flow in the main Flowdock::REST object or when using send_chat_message"; }

		$message->{event} or croak "You must specify an event";
		my %params;
		if ($message->{event} eq 'message' || $message -> {event} eq 'status') {
			%params = (
				event => $message->{event},
				content => $message->{content});
			my $tags;
			if ($message->{tags} && ref($message->{tags}) ne 'ARRAY') { croak "Tags must be in an array; e.g. ['foo', 'bar']"; }
			if ($message->{tags} && scalar(@{$message->{tags}}) > 0) { $tags = join(",",@{$message->{tags}}); }
			$params{tags} = $tags if $tags;
		}

		elsif ($message->{event} eq 'mail') {
			$message->{content} && $message->{subject} or croak "Message must have both subject and content";
			$message->{address} or croak "The message is missing the address attribute";
			$message->{source} && $message->{source} =~ /^[0-9a-z_ ]+$/i or croak "The flow must have a valid source attribute when posting to the Team Inbox and must only contain alphanumeric characters, underscores, or spaces.";
			# Parameters to include in the POST
			%params = (
				source => $message->{source},
				event => $message->{event},
				format => 'html', #The only format supported for now
				from_address => $message->{address},
				subject => $message->{subject},
				content => $message->{content});
			# Optional parameters
			$params{from_name} = $message->{name} if $message->{name};
			$params{project} = $message->{project} if $message->{project};
			$params{link} = $message->{link} if $message->{link};

			my $tags;
			if ($message->{tags} && ref($message->{tags}) ne 'ARRAY') {
				croak "Tags must be in an array; e.g. ['foo', 'bar']";
			}
			if ($message->{tags} && scalar(@{$message->{tags}}) > 0) {
				$tags = join(",",@{$message->{tags}});
			}
			$params{tags} = $tags if $tags;

		}
		else { croak "You must use an event of type 'message', 'status', or 'mail'."; }


		my $json_params = encode_json \%params;
		return $self->rest_action_post($url, $json_params);

	}

}

=head2 rest_action_get

Performs the GET actions

=cut

sub rest_action_get {
	my ($self, $url) = @_;
	my $client = REST::Client->new();
	$client->GET($url);
	my $json_body = decode_json $client->responseContent();
	return $json_body;
}

=head2 rest_action_post

Performs the POST actions

=cut

sub rest_action_post {
	my ($self, $url, $param) = @_;
	my $client = REST::Client->new();
	if ($param) { $client->POST($url, $param, {"Content-type" => 'application/json'}); }
	else { croak "This action is empty." }
	print "Success! Message posted.\n" if $client->responseCode() eq '200';
	return $client->responseContent();

}

=head2 get_flowdock_api_url

Constructs the proper URL; i.e., separates the various parts with /

=cut

sub get_flowdock_api_url {
	my ($self, @url_parts) = @_;
	my $url = $base_url;
	for my $part (@url_parts) {
		$url.="/$part";
	}
	return $url;
}
__PACKAGE__->meta->make_immutable;

1;
