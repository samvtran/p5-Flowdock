package Flowdock::Tag;
use strict;
use warnings;

sub new {
	my ($self, $tags) = @_;
	my $tags_formatted;
	if (ref($tags) eq 'ARRAY') {
		$tags_formatted = join(",",@{$tags});
	}
	elsif (!ref($tags)) {
		$tags_formatted = $tags;
	}
	return $tags_formatted;
}
1;
