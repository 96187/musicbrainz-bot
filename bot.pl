#!/usr/bin/perl
# perl bot.pl [options]

use FindBin;
use lib "$FindBin::Bin";

use MusicBrainzBot;
use DBI;
use Getopt::Long;

my $username = "";
my $password = "";
my $server = "";
my $verbose = 0;
my $max = 100;

GetOptions('username|u=s' => \$username, 'password|p=s' => \$password, 'server' => \$server, 'verbose|v' => \$verbose, 'max|m=i' => \$max);

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
$bot->login();

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("select r.gid, r.comment from recording r where r.comment ~ E'^live, [0-9-]+: Olympia, Paris\$'");
$sth->execute;

while (my ($mbid, $comment) = $sth->fetchrow()) {
	unless ($max > 0) {
		print "Reached maximum number of files.\n";
		last;
	}

	my $comment_orig = $comment;
	$comment =~ s/Paris$/Paris, France/;

	print "Editing comment for $mbid from $comment_orig to $comment\n" if $verbose;
	# TODO: Move the field prefixes to the edit_* functions
	my $rv = $bot->edit_recording($mbid, { 'edit-recording.edit_note' => 'Adding missing country', 'edit-recording.comment' => $comment });

	$max -= $rv;
}

#$dbh->disconnect(); # TODO: This fails when quitting if it's not finished fetching all the rows

