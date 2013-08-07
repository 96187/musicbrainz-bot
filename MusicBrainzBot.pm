#!/usr/bin/perl

package MusicBrainzBot;
use utf8;
use WWW::Mechanize;

sub new {
	my ($package, $args) = @_;
	my %hash;
	%hash = (
		'server' => $args->{server} || 'musicbrainz.org',
		'username' => $args->{username},
		'password' => $args->{password},
		'useragent' => 'MusicBrainz bot/0.1',
		'verbose' => $args->{verbose},
		'mech' => WWW::Mechanize->new(agent => $self->{'useragent'}, autocheck => 1),
	);
	bless \%hash => $package;
}

sub login {
	my ($self) = @_;
	my $mech = $self->{'mech'};

	if (!$self->{'username'}) {
		print "Username: ";
		$self->{'username'} = <>;
		chomp($self->{'username'});
		print "\n";
	}

	if (!$self->{'password'}) {
		system "stty -echo";
		print "Password for ".$self->{'username'}.": ";
		$self->{'password'} = <>;
		system "stty echo";
		print "\n";
	}

	# load login page
	my $url = "https://".$self->{'server'}."/login";
	print "Logging in as ".$self->{'username'}." at $url.\n" if $self->{'verbose'};
	$mech->get($url);
	sleep 1;

	# submit login page
	my $r = $mech->submit_form(
		form_number => 2,
		fields => {
			username => $self->{'username'},
			password => $self->{'password'},
		}
	);
	sleep 1;

	if (!$mech->find_link(url => "https://".$self->{'server'}."/logout")) {
		die "Login failed.\n";
	}

	$self->{'loggedin'} = 1;
}

sub edit_area {
	my ($self, $mbid, $opt) = @_;

	return $self->edit_entity("area", $mbid, $opt);
}

sub edit_artist {
	my ($self, $mbid, $opt) = @_;

	return $self->edit_entity("artist", $mbid, $opt);
}

sub edit_release_group {
	my ($self, $mbid, $opt) = @_;

	return $self->edit_entity("release-group", $mbid, $opt);
}

# the release editor differs from the other forms
#sub edit_release {
#}

sub edit_recording {
	my ($self, $mbid, $opt) = @_;

	return $self->edit_entity("recording", $mbid, $opt);
}

sub edit_work {
	my ($self, $mbid, $opt) = @_;

	return $self->edit_entity("work", $mbid, $opt);
}

sub edit_label {
	my ($self, $mbid, $opt) = @_;

	return $self->edit_entity("label", $mbid, $opt);
}

sub edit_url {
	my ($self, $mbid, $opt) = @_;

	return $self->edit_entity("url", $mbid, $opt);
}

sub add_url_relationship {
	my ($self, $id, $entity, $opt) = @_;
	my $mech = $self->{'mech'};

	die "No ID provided" unless $id;
	die "No entity provided" unless $entity;

	$self->login() if !$self->{'loggedin'};

	my $url = "https://".$self->{'server'}."/edit/relationship/create_url?type=$entity&entity=$id";
#	print "$url\n";
	$mech->get($url);

	$mech->form_number(2);
	if ($mech->find_all_inputs(type => 'checkbox', name => "ar.as_auto_editor")) {
		$mech->untick("ar.as_auto_editor", "1");
	}
	for my $k (keys %$opt) {
		$mech->field("ar.$k", $opt->{$k});
	}
	my $r = $mech->submit();
	sleep 1;

	# TODO: Check that submitting worked.

	return 1;
}

sub add_relationship {
	my ($self, $entity0, $entity1, $type0, $type1, $opt) = @_;
	my $mech = $self->{'mech'};

	die "No entities provided" unless $entity0 && $entity1;
	die "No entity types provided" unless $type0 && $type1;

	$self->login() if !$self->{'loggedin'};

	my $url = "https://".$self->{'server'}."/edit/relationship/create?entity0=$entity0&entity1=$entity1&type0=$type0&type1=$type1";
	print "$url\n";
	$mech->get($url);

	$mech->form_number(2);
	if ($mech->find_all_inputs(type => 'checkbox', name => "ar.as_auto_editor")) {
		$mech->untick("ar.as_auto_editor", "1");
	}
	for my $k (keys %$opt) {
		$mech->field("ar.$k", $opt->{$k});
	}
	my $r = $mech->submit();
	sleep 1;

	# TODO: Check that submitting worked.

	return 1;
}

sub edit_relationship {
	my ($self, $id, $entity0, $entity1, $opt) = @_;
	my $mech = $self->{'mech'};

	die "No ID provided" unless $id;
	die "No entities provided" unless $entity0 && $entity1;

	$self->login() if !$self->{'loggedin'};

	my $url = "https://".$self->{'server'}."/edit/relationship/edit?id=$id&type0=$entity0&type1=$entity1";
	print "$url\n";
	$mech->get($url);

	$mech->form_number(2);
	if ($mech->find_all_inputs(type => 'checkbox', name => "ar.as_auto_editor")) {
		$mech->untick("ar.as_auto_editor", "1");
	}
	for my $k (keys %$opt) {
		$mech->field("ar.$k", $opt->{$k});
	}
	my $r = $mech->submit();
	sleep 1;

	# TODO: Check that submitting worked.

	return 1;

}

sub edit_entity {
	my ($self, $entity, $mbid, $opt) = @_;
	my $mech = $self->{'mech'};

	die "No MBID provided" unless $mbid;

	$self->login() if !$self->{'loggedin'};

	my $url = "https://".$self->{'server'}."/$entity/$mbid/edit";
#	print "$url\n";
	$mech->get($url);

	$mech->form_number(2);
	if ($mech->find_all_inputs(type => 'checkbox', name => "edit-$entity.as_auto_editor")) {
		$mech->untick("edit-$entity.as_auto_editor", "1");
	}
	for my $k (keys %$opt) {
		$mech->field("edit-$entity.$k", $opt->{$k});
	}
	my $r = $mech->submit();
	sleep 1;

	# TODO: Check that submitting worked.

	return 1;
}

sub add_entity {
	my ($self, $entity, $opt, $mbid) = @_;
	my $mech = $self->{'mech'};

	$self->login() if !$self->{'loggedin'};

	my $url = "https://".$self->{'server'}."/$entity/create";
	$url .= "?artist=$mbid" if $mbid;
#	print "$url\n";
	$mech->get($url);

	$mech->form_number(2);
	if ($mech->find_all_inputs(type => 'checkbox', name => "edit-$entity.as_auto_editor")) {
		$mech->untick("edit-$entity.as_auto_editor", "1");
	}
	for my $k (keys %$opt) {
		$mech->field("edit-$entity.$k", $opt->{$k});
	}
	my $r = $mech->submit();
	sleep 1;

	if ($mech->uri() =~ /\/([0-9a-f-]{36})$/) {
		return $1;
	} else {
		return 0;
	}

	return -1;
}

sub add_area {
	my ($self, $opt) = @_;

	return $self->add_entity("area", $opt);
}

sub add_artist {
	my ($self, $opt) = @_;

	return $self->add_entity("artist", $opt);
}

sub add_release_group {
	my ($self, $mbid, $opt) = @_;

	return $self->add_entity("release-group", $opt, $mbid);
}

# the release editor differs from the other forms
#sub add_release {
#}

sub add_recording {
	my ($self, $mbid, $opt) = @_;

	return $self->add_entity("recording", $opt, $mbid);
}

sub add_work {
	my ($self, $opt) = @_;

	return $self->add_entity("work", $opt);
}

sub add_label {
	my ($self, $opt) = @_;

	return $self->add_entity("label", $opt);
}

sub set_release_group_tags {
	my ($self, $mbid, $opt) = @_;

	return $self->set_tags("release-group", $mbid, $opt);
}

sub set_tags {
	my ($self, $entity, $mbid, $opt) = @_;
	my $mech = $self->{'mech'};

	die "No MBID provided" unless $mbid;

	$self->login() if !$self->{'loggedin'};

	my $url = "https://".$self->{'server'}."/$entity/$mbid/tags";
	print "$url\n";
	$mech->get($url);

	$mech->form_number(2);
	for my $k (keys %$opt) {
		$mech->field("tag.$k", $opt->{$k});
	}
	my $r = $mech->submit();
	sleep 1;

	# TODO: Check that submitting worked.

	return 1;
}

sub add_alias {
	my ($self, $id, $entity, $opt) = @_;
	my $mech = $self->{'mech'};

	die "No ID provided" unless $id;
	die "No entity provided" unless $entity;

	$self->login() if !$self->{'loggedin'};

	my $url = "https://".$self->{'server'}."/$entity/$id/add-alias";
	print "$url\n";
	$mech->get($url);

	$mech->form_number(2);
	if ($mech->find_all_inputs(type => 'checkbox', name => "ar.as_auto_editor")) {
		$mech->untick("ar.as_auto_editor", "1");
	}
	for my $k (keys %$opt) {
		$mech->field("edit-alias.$k", $opt->{$k});
	}
	my $r = $mech->submit();
	sleep 1;

	# TODO: Check that submitting worked.

	return 1;
}

1;
