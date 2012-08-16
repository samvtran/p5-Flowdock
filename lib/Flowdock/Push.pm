package Flowdock::Push;
use strict;
use warnings;
use Carp;
use Moo;
use HTTP::Tiny;
use Email::Valid;
use MIME::Base64;
use namespace::autoclean;

=head1 NAME

Flowdock::Push - An interface to the Flowdock Push API for chat and the Team Inbox

=head1 TODO

Use Moose for more/most of this if possible.
Better pod documentation

=cut

has api_token => (
	is => 'ro');

has source => (
	is => 'ro');

has project => (
	is => 'ro');

has from => (
	is => 'ro',
	isa => sub {
		croak '\%from is not a hash reference' unless ref($_[0]) eq 'HASH';
		croak '\%from does not contain a valid email address'
			unless $_[0]->{address} && Email::Valid->address($_[0]->{address});
	});

has base_url => (
	is => 'rw',
	default => sub { return 'https://api.flowdock.com/v2/messages'; });

has http_client => (
	is => 'rw',
	isa => sub {
		croak "$_[0] must be an HTTP::Tiny client" unless ref($_[0]) eq 'HTTP::Tiny';
	},
	default => sub {
		return HTTP::Tiny->new;
	});

has basic_auth => (
	is => 'rw');

=head1 METHODS

=head2 new

my $pusher = Flowdock::Push->new($api_token, $source, \%from)

Builds the initial Flowdock Push object.

Required: api_token, source, \%from->{address}
Optional: project, \%from->{name}

=cut

sub BUILD {
	my $self = shift;
	$self->api_token()
		or croak "Flow must have api_token attribute";
	$self->basic_auth('Basic '.encode_base64($self->api_token(), q{}));
	# Source is only required for send_message, so keep it here so you don't have to repeat, but check in send_message
	if ($self->source() && $self->source() !~ /^[0-9a-z_ ]+$/i) {
	    croak "Optional source attribute can only contain alphanumeric characters and underscores"; }
	if ($self->project() && $self->project() !~ /^[0-9a-z_ ]+$/i) {
		croak "Optional attribute project can only contain alphanumeric characters and underscores"; }
	$self->from() && $self->from()->{address} or croak "Must have an address!";
	$self->http_client(HTTP::Tiny->new(
		default_headers => {
			'Authorization' => $self->basic_auth,
		},
	));
}

=head2 push_to_team_inbox

$pusher->push_to_team_inbox($content, $subject, \%from->{name}, $project, $link, $tags|\@tags)

Sends a message to the Team Inbox

Required: content, subject
Optional: from_name, project, link, tags (comma-separated or arrayref)

=cut

sub push_to_team_inbox {
	my ($self, @messages) = @_;
	for my $message (@messages){
		$message->{content} && $message->{subject} or croak "Message must have both subject and content";
		$self->from()->{address} or croak "The flow's from attribute is missing the address attribute";
		$self->source() or croak "The flow must have a valid source attribute when posting to the Team Inbox";

		# Required (also format, which isn't required)
		my $params = {
			source       => $self->source(),
			format       => 'html', #The only format supported for now
			from_address => $self->from()->{address},
			subject      => $message->{subject},
			content      => $message->{content}
		};

		# Optional parameters
		$params->{from_name} = $self->from()->{name} if $self->from()->{name};
		$params->{project}   = $self->project() if $self->project();
		$params->{link}      = $message->{link} if $message->{link};

		if($message->{tags}) {
			$params->{tags} = $message->{tags} eq 'ARRAY'
				? join(',', $message->{tags}) : $message->{tags};
		}

		my $send = $self->_post('team_inbox', $params);
	}
}

=head2 push_to_chat

$pusher->push_to_chat($content, $external_user_name, \@tags)

Sends a chat message

Required: content, external_user_name
Optional: tags

=cut

sub push_to_chat {
	my ($self, @messages) = @_;
	for my $message (@messages){
		$message->{content} && length $message->{content} <= 8096 or croak "Message must have content and be less than 8096 characters.";
		$message->{external_user_name} or croak "Must have external_user_name";
		$message->{external_user_name} =~ /^[\S]+$/i or croak "Username cannot have whitespace";


		# Required params
		my $params = {
			content            => $message->{content},
			external_user_name => $message->{external_user_name}
		};

		# Optional tags
		if($message->{tags}) {
			$params->{tags} = $message->{tags} eq 'ARRAY'
				? join(',', $message->{tags}) : $message->{tags};
		}

		my $send = $self->_post('chat', $params);
	}
}

=head2 _post

POST message to Flowdock

=cut

sub _post {
	my ($self, $location, $params) = @_;
	my $url = $self->_get_api_url($location);
	my $response = $self->http_client->post_form($url, $params);
	croak "$response->{status} $response->{reason}\n $response->{content}\n" unless $response->{success};
	print "Success! $response->{status}\n";
	return 1;
}

=Head2 _get_api_url

Constructs the proper URL; i.e., separates the various parts with /

=cut

sub _get_api_url {
	my ($self, $location) = @_;
	return $self->base_url()."/$location/".$self->api_token();
}

__PACKAGE__->meta->make_immutable;

1;
