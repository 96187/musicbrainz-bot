#!/usr/bin/perl
# perl bot.pl [options]

use FindBin;
use lib "$FindBin::Bin";

use MusicBrainzBot;
use DBI;
use Getopt::Long;
use Storable;

my $username = "";
my $password = "";
my $server = "";
my $verbose = 0;
my $max = 100;
my $dryrun = 0;

GetOptions('username|u=s' => \$username, 'password|p=s' => \$password, 'server' => \$server, 'verbose|v' => \$verbose, 'max|m=i' => \$max, 'dryrun' => \$dryrun);

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
$bot->login();

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("select r.gid, r.comment from recording r where r.comment ~ E'^live' and r.edits_pending = 0 order by r.comment asc");
$sth->execute;

my $previous = retrieve('previousdata');

while (my ($mbid, $comment) = $sth->fetchrow()) {
	unless ($max > 0) {
		print "Reached maximum number of files.\n";
		last;
	}

	my @notes = ();
	my $comment_orig = $comment;

# TODO: This next section is really repetitive and has too many s///.

#	Standardising formatting
	if (!$previous->{$mbid}{'initial format'}) {
		my $tmp = $comment;
		$comment =~ s/^live(?:,|:? )([0-9-]+(:|$))/live, $1/;
#		$comment =~ s/^live, ([0-9-]+)[,:]? /live, $1: /; # This line needs improvement, currently would edit things it shouldn't
		$comment =~ s/ ([A-Z]{2}) (USA)$/ $1, $2/;
		push @notes, "Standardising formatting" if $comment ne $tmp;
		$previous->{$mbid}{'initial format'}++ if $comment ne $tmp;
	}

	# Standardise date format
	if (!$previous->{$mbid}{'date format'}) {
		my $tmp = $comment;
		$comment =~ s/^(live, [0-9]{4})-([0-9])([:-]|$)/$1-0$2$3/;
		$comment =~ s/^(live, [0-9]{4}-[0-9]{2})-([0-9])(:|$)/$1-0$2$3/;
		push @notes, "Standardising date format" if $comment ne $tmp;
		$previous->{$mbid}{'date format'}++ if $comment ne $tmp;
	}

	# Add missing countries
	if (!$previous->{$mbid}{'missing country'}) {
		my $tmp = $comment;
		$comment =~ s/: Olympia, Paris$/: Olympia, Paris, France/;
		push @notes, "Adding missing country" if $comment ne $tmp;
		$previous->{$mbid}{'missing country'}++ if $comment ne $tmp;
	}

	# Standardise country names
	if (!$previous->{$mbid}{'country names'}) {
		my $tmp = $comment;
		$comment =~ s/([,:] )The Netherlands$/$1Netherlands/;
		$comment =~ s/([,:] )Holland$/$1Netherlands/;
		$comment =~ s/([,:] )United Kingdom$/$1UK/;
		$comment =~ s/([,:] )United States$/$1USA/;
		$comment =~ s/([,:] )JPN$/$1Japan/;
		$comment =~ s/([,:] )FR$/$1France/;
		$comment =~ s/([,:] )DK$/$1Denmark/;
		$comment =~ s/([,:] )SE$/$1Sweden/;
		$comment =~ s/([,:] )CH$/$1Switzerland/;
		$comment =~ s/([,:] )DE$/$1Germany/;
		$comment =~ s/([,:] )SU$/$1Soviet Union/;
		$comment =~ s/([,:] )PL$/$1Poland/;
		$comment =~ s/([,:] )BE$/$1Belgium/;
		$comment =~ s/([,:] )NL$/$1Netherlands/;
		push @notes, "Standardising country name" if $comment ne $tmp;
		$previous->{$mbid}{'country names'}++ if $comment ne $tmp;
	}

	next if $comment_orig eq $comment;
	print "Editing comment for $mbid from $comment_orig to $comment\n" if $verbose;
	my $rv = $bot->edit_recording($mbid, { 'edit_note' => join ("\n", @notes), 'comment' => $comment }) unless $dryrun;
	$max -= $rv;
}

# TODO: This file is going to get huge. Should generate a second hash of edited things which were still found and save that instead.
store $previous, 'previousdata' unless $dryrun;

#$dbh->disconnect(); # TODO: This fails when quitting if it's not finished fetching all the rows

