package Flowdock::REST;
use strict;
use warnings;
use Moo;
use Carp;
use HTTP::Tiny;
use JSON::XS;
use Email::Valid;
use MIME::Base64;
use URI::Encode qw/uri_encode uri_decode/;
use namespace::autoclean;
use v5.10.1;

=head1 NAME

Flowdock::REST - An interface to Flowdock's REST API

=cut

has username => (
	is => 'ro',
	isa => sub {
		croak "$_[0] is not an email address" unless Email::Valid->address($_[0]);
	});

has password => (
	is => 'ro');

has personal_token => (
	is => 'ro');

has org => (
	is => 'ro');

has flow => (
	is => 'rw');

has messages => (
	is => 'ro',
	isa => sub {
		croak "$_[0] is not an array reference" unless ref($_[0]) eq 'ARRAY';
	});

has base_url => (
	is => 'rw',
	default => sub { return "https://api.flowdock.com/v2"; });

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

Flowdock::REST->new(\%parameters);

Constructs the REST object.

Required: username/password or personal_token
Optional: org, flow, messages
NOTE: This flow is used only if a flow isn't explicitly passed elsewhere.

=cut

sub BUILD {
	my $self = shift;
	if ($self->username) {
		$self->password or croak "You forgot to enter a password.";
		$self->basic_auth('Basic '.encode_base64($self->username.":".$self->password, q{}));
	} elsif ($self->personal_token) {
		$self->basic_auth('Basic '.encode_base64($self->personal_token, q{}));
	} else { croak "You must supply your username/password or a personal token"; }
	$self->org() or croak "Must have an organization set";
	$self->http_client(HTTP::Tiny->new(
		default_headers => {
			'Authorization' => $self->basic_auth,
		},
	));
}

=head2 list_flows

$rest->list_flows($boolean);

Lists all flows for a user.

Optional: boolean indicating whether to include the users in a flow or not

=cut

sub list_flows {
	my ($self, $users) = @_;
	$users = $users ? $users : 0;
	my $response = $self->_get($self->base_url(), {users => $users});
	return decode_json $response;
}

=head2 get_flow

$rest->get_flow($flow_name);

Gets a particular flow's information

Optional: flow
NOTE: By leaving flow out, you must have flow from the Flowdock::REST object set.

=cut

sub get_flow {
	my ($self, $flow) = @_;
	my $url = $self->_get_api_url($self->{org}, $flow ? $flow : $self->{flow});
	return decode_json $self->_get($url);
}

=head2 get_files

$rest->get_files($save_path, $file_path);
$rest->get_files($save_path, [$file1, $file2]);

Get files and saves them to the proper path

Required: array of file paths, path to save files, without trailing slash

Note: Paths come in the form of /flows/:org/:flow/files/:filename, so
flow and organiation are already part of the filename.

=cut

sub get_files {
	my ($self, $save_path, $file_names) = @_;
	foreach my $file_name (@$file_names) {
		print "Getting: ".$self->base_url().$file_name."\n";
		my $response = HTTP::Tiny->new(
				max_redirect    => 0,
				default_headers => {
					'Authorization' => $self->basic_auth,
				}
		)->get($self->base_url().uri_encode($file_name));
		my $file = HTTP::Tiny->new()->get($response->{headers}->{location});
		my $new_name = uri_decode($file->{headers}->{'x-amz-meta-name'});
		open(my $saved_file, '>', $save_path."/".$new_name)
			or croak "Couldn't save file at $save_path";
		print $saved_file $file->{content}
			or croak "Couldn't save file at $save_path";
		print "Saved file at $new_name\n";
		close $saved_file;
	}
}

=head2 send_message

$rest->send_message(\%message);
$rest->send_message([\%message,\%message2,...]);

Sends a message to the inbox or chat or sets the status of the user

Required: event, content
Optional: flow, tags, external_user_name (anonymizes message)

NOTE: By leaving flow out, you must have flow from the Flowdock::REST object set.

Current events and their required elements

message | content
status | content
file | content (full path to file), file_name

Note: Action is probably only for the streaming API, but it potentially works here
action | content => { type, description }

Note: These actions are currently in a volatile state
comment | content
tag-change | content => { message, add, remove }
user | content

=cut

sub send_message {
	my ($self, @messages) = @_;
	for my $message (@messages) {
		my $flow = $message->{flow} ? $message->{flow} : $self->{flow};
		$flow or croak "You must specify a flow";
		$message->{content} or croak "Your message must have content";
		$message->{event} or croak "You must specify an event";

		my $url = $self->_get_api_url($self->{org}, $flow , 'messages');
		my $params = {event => $message->{event}};

		given($message->{event}) {
			when('message') {
				$params->{content} = $message->{content};
				if($message->{tags}) {
					$params->{tags} = $message->{tags} eq 'ARRAY'
						? join(',', $message->{tags}) : $message->{tags};
				}
				$self->_post($url, $params);
			}
			when('file') {
				$message->{file_name} or croak "You must provide a file name";
				open (my $fh, '<', $message->{content})
					or croak "Couldn't open file.";
				binmode $fh;
				$params->{content} = {
					data      => encode_base64(local $/ = <$fh>),
					file_name => $message->{file_name},
				};
				$self->_post_file($url, encode_json $params);
				close $fh;
			}
			when('action') {
				$message->{content}->{type} or croak "Must have a type for action";
				$params->{content} = {
					type        => $message->{content}->{type},
					description => $message->{content}->{description},
				};
				$self->_post($url, $params);
			}
			default {
				$params->{content} = $message->{content};
				$self->_post($url, $params);
			}
		}
	}

}

=head2 list_messages

$rest->list_messages(\%filter_params);
$rest->list_messages([\%params1, \%params2,...]);

Lists messages from a flow or multiple flows

Parameters:
event (can be comma separated list in a string)
limit
sort: 'asc' or defaults to descending
since_id
until_id
tags: comma separated or array. Can also search by user ID
tag_mode: 'and' (default) or 'or'
search: full text search by keywords separated by spaces

Returns an array containing all

=cut

sub list_messages {
	my ($self, @messages) = @_;
	my $responses = [];
	for my $message (@messages) {
		my $flow = $message->{flow} ? delete $message->{flow} : $self->{flow};
		croak "You must specify a flow" unless $flow;
		my $url = $self->_get_api_url($self->{org}, $flow , 'messages');
		my $params = ();
		if($message->{tags}) {
			$params->{tags} = $message->{tags} eq 'ARRAY' ? join(',', $message->{tags}) : $message->{tags};
			delete $message->{tags};
		}
		while(my($k, $v) = each %$message) {
			$params->{$k} = $v;
		}
		my $response = $self->_get($url, $params);
		push @$responses, decode_json $response;
	}
	return $responses;
}

=head2 _get

Performs the GET actions

=cut

sub _get {
	my ($self, $url, $params) = @_;
	$params = $params ? "?".$self->http_client->www_form_urlencode($params) : '';
	my $response = $self->http_client->get($url.$params);
	$response->{success} or croak "$response->{status} $response->{reason}\n" ;
	return $response->{content};
}

=head2 _post

Performs the POST actions for forms

=cut

sub _post {
	my ($self, $url, $params) = @_;
	my $response = $self->http_client->post_form($url, $params);
	croak "$response->{status} $response->{reason}\n $response->{content}\n" unless $response->{success};
	print "Success! $response->{status}\n";
	return 1;
}

=head2 _post_file

Performs a POST action for files using JSON

=cut

sub _post_file {
	my ($self, $url, $params) = @_;
	my $response = $self->http_client->post($url, {
		content => $params,
		headers => {
			'Content-Type' => 'application/json',
			'Authorization' => $self->basic_auth,
		}
	});
	croak "$response->{status} $response->{reason}\n" unless $response->{success};
	print "Success! $response->{status}\n";
	return 1;
}

=head2 _get_api_url

Constructs the proper URL; i.e., separates the various parts with /

=cut

sub _get_api_url {
	my $self = shift;
	my (@url_parts) = @_;
	my $url = $self->base_url()."/flows"."/".join('/', @url_parts);
	return $url;
}

__PACKAGE__->meta->make_immutable;

1;
