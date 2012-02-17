package Flowdock::REST;
use Flowdock::Tag;
use Carp;
use Moose;
use Moose::Util::TypeConstraints;
use LWP::UserAgent;
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

has base_url => (
	is => 'rw',
	isa => 'Str');

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
		$self->base_url("https://".$self->username().":".$self->password()."\@api.flowdock.com/v2/flows");
	} elsif ($self->personal_token()) {
		$self->base_url("https://".$self->personal_token()."\@api.flowdock.com/v2/flows");
	} else { croak "You must supply either username/password or a personal token"; }
}

=head2 list_flows

Lists all flows for a user.

Optional: 1/0 boolean indicating whether to include the users in a flow or not

=cut

sub list_flows {
	my ($self, $users) = @_;
	unless ($users) { $users = 0; }
	my $response = $self->rest_action_get($self->base_url()."?users=".$users);
	return $response;
}

=head2 get_flow

Gets a particular flow's information

Optional: flow
NOTE: By leaving flow out, you must have flow from the Flowdock::REST object set.

=cut

sub get_flow {
	my ($self, $flow) = @_;
	my $url;
	if ($flow) { $url = $self->get_flowdock_api_url($self->{org}, $flow); }
	elsif ($self->{flow}) { $url = $self->get_flowdock_api_url($self->{org}, $self->{flow}); }
	else { croak "You must provide flow through the Flowdock::REST object or when using get_flow()"; }
	return $self->rest_action_get($url);
}

=head2 send_message

Sends a message to the inbox or chat or sets the status of the user

Required for all: event, content
Required for mail: subject, address, source
Optional for all: flow, tags
Optional for mail: from_name, project, link

NOTE: By leaving flow out, you must have flow from the Flowdock::REST object set.

=cut

sub send_message {
	my ($self, @messages) = @_;
	my $url;
	for my $message (@messages) {
		if ($message->{flow}) { $url = $self->get_flowdock_api_url($self->{org}, $message->{flow}, 'messages'); }
		elsif ($self->{flow}) { $url = $self->get_flowdock_api_url($self->{org}, $self->{flow}, 'messages'); }
		else { croak "You must specify a flow in the main Flowdock::REST object or when using send_chat_message"; }

		$message->{content} or croak "Your message must have content";
		$message->{event} or croak "You must specify an event";

		my %params;
		if ($message->{event} eq 'message' || $message -> {event} eq 'status') {
			%params = (
				event => $message->{event},
				content => $message->{content});
			my $tags;
			if ($message->{tags}) { $tags = Flowdock::Tag->new($message->{tags}); }
			$params{tags} = $tags if $tags;
		}

		elsif ($message->{event} eq 'mail') {
			$message->{subject} && $message->{address} or croak "The message is missing a subject and/or the address attribute";
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
			if ($message->{tags}) { $tags = Flowdock::Tag->new($message->{tags}); }
			$params{tags} = $tags if $tags;

		}
		else { croak "You must use an event of type 'message', 'status', or 'mail'."; }

		#my $json_params = encode_json \%params;
		#$self->rest_action_post($url, $json_params);
		$self->rest_action_post($url, \%params);
	}

}

=head2 rest_action_get

Performs the GET actions

=cut

sub rest_action_get {
	my ($self, $url) = @_;
	my $ua = LWP::UserAgent->new;
	my $response;
	$response = $ua->get($url);
	return decode_json $response->decoded_content;
}

=head2 rest_action_post

Performs the POST actions

=cut

sub rest_action_post {
	my ($self, $url, $params) = @_;
	my $ua = LWP::UserAgent->new;
	my $response = $ua->post( $url, Content => $params);
	if ($response->is_success) {
		print "Success! Your message has been sent to Flowdock.\n";
	} else {
		die $response->status_line;
	}

}

=head2 get_flowdock_api_url

Constructs the proper URL; i.e., separates the various parts with /

=cut

sub get_flowdock_api_url {
	my ($self, @url_parts) = @_;
	my $url = $self->base_url();
	for my $part (@url_parts) {
		$url.="/$part";
	}
	return $url;
}
__PACKAGE__->meta->make_immutable;

1;
