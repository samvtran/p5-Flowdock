package Flowdock::Push;
use Carp;
use Moose;
use LWP::UserAgent;
use namespace::autoclean;

=head1 NAME

Flowdock::Push - An interface to the Flowdock Push API for chat and the Team Inbox

=head1 TODO

Use Moose for more/most of this if possible.
Better pod documentation

=cut

# Instead of using required, we're using the croaks in BUILD for custom error messages.
# There's a better way to do this for sure.
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

my $flowdock_api_url = "https://api.flowdock.com/v1/messages";

=head1 METHODS

=head2 BUILD

Builds the initial Flowdock Push object.

Required: api_token
Optional: source, project

=cut

sub BUILD {
	my $self = shift;
	$self->api_token()
	    or croak "Flow must have api_token attribute";
	# Source is only required for send_message, so keep it here so you don't have to repeat, but check in send_message
	if ($self->source() && $self->source() !~ /^[0-9a-z_ ]+$/i) {
	    croak "Optional source attribute can only contain alphanumeric characters and underscores"; }
	if ($self->project() && $self->project() !~ /^[0-9a-z_ ]+$/i) {
		croak "Optional attribute project can only contain alphanumeric characters and underscores"; }

}

=head2 send_inbox_message

Sends a message to the Team Inbox

Required: content, subject, source, address
Optional: from_name, project, link, tags

=cut

sub send_inbox_message {
	my ($self, @messages) = @_;
	for my $message (@messages){
		$message->{content} && $message->{subject} or croak "Message must have both subject and content";
		$self->from()->{address} or croak "The flow's from attribute is missing the address attribute";

		$self->{source} or croak "The flow must have a valid source attribute when posting to the Team Inbox";
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

		my $send = $self->post_message(\%params,'team_inbox');
	}
}

=head2 send_chat_message

Sends a chat message

Required: content, external_user_name
Optional: tags

=cut

sub send_chat_message {
	my ($self, @messages) = @_;
	for my $message (@messages){
		$message->{content} or croak "Message must have content.";
		# TODO Figure out what isn't acceptable for user names
		$message->{external_user_name} #&& $message->{external_user_name} =~ /^[0-9a-z_]+$/i #No spaces for sure, what else though?
		    or croak "Must have external_user_name";

		# Parameters to include in the POST
		my %params = (
			content => $message->{content},
			external_user_name => $message->{external_user_name});

		# Optional tags
		my $tags;
		if ($message->{tags} && ref($message->{tags}) ne 'ARRAY') { croak "Tags must be in an array; e.g. ['foo', 'bar']"; }
		if ($message->{tags} && scalar(@{$message->{tags}}) > 0) { $tags = join(",",@{$message->{tags}}); }
		$params{tags} = $tags if $tags;

		my $send = $self->post_message(\%params, 'chat');
	}
}

=head2 post_message

Uses LWP::UserAgent to POST the message

=cut

sub post_message {
	my ($self, $params, $location) = @_;
	my $ua = LWP::UserAgent->new;
	my $url = $self->get_flowdock_api_url($location);
	my $response = $ua->post( $url, Content => $params);
	if ($response->is_success) {
		print "Success! Your message has been sent to Flowdock.\n";
	} else {
		die $response->status_line;
	}
}

=Head2 get_flowdock_api_url

Constructs the correct URL

=cut

sub get_flowdock_api_url {
	my ($self, $location) = @_;
	return "$flowdock_api_url/$location/".$self->api_token();
}

__PACKAGE__->meta->make_immutable;

1;
