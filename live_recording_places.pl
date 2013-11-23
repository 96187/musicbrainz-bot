#!/usr/bin/perl
# perl bot.pl [options]

use FindBin;
use lib "$FindBin::Bin";
use utf8;

use MusicBrainzBot;
use DBI;
use Getopt::Long;

require "live_recording_places_mapping.pl";
my %mapping = mapping();

my $username = "";
my $password = "";
my $server = "beta.musicbrainz.org";
my $verbose = 0;
my $max = 1000;
my $dryrun = 0;

GetOptions('username|u=s' => \$username, 'password|p=s' => \$password, 'server' => \$server, 'verbose|v' => \$verbose, 'max|m=i' => \$max, 'dryrun' => \$dryrun);

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose, protocol => "https://" });
$bot->login() unless $dryrun;

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("select d.gid, d.comment from recording d left join l_place_recording lpd on lpd.entity1=d.id where d.comment != '' and d.comment ~ '^live, [0-9]{4}(-[0-9]{2}){0,2}: .*, (Germany|Japan)\$' and lpd.id is null and d.edits_pending = 0 order by d.comment");
$sth->execute;

while (my ($mbid, $name) = $sth->fetchrow()) {
	unless ($max > 0) {
		print "Reached maximum number of files.\n";
		last;
	}

	next unless $name =~ /^live, ([0-9]{4})(?:-([0-9]{2}))(?:-([0-9]{2})): (.*)$/;
	my ($y, $m, $d, $loc) = ($1, $2, $3, $4);
	next unless $mapping{$loc};

	print "Editing $name ($mbid)\n" if $verbose;
	my $rv = $bot->add_relationship($mbid, $mapping{$loc}, "recording", "place", {
		"link_type_id" => 693,
		'period.begin_date.year' => $y,
		'period.begin_date.month' => $m,
		'period.begin_date.day' => $d,
		'period.end_date.year' => $y,
		'period.end_date.month' => $m,
		'period.end_date.day' => $d,
		'as_auto_editor' => 1,
		'edit_note' => 'from recording disambiguation'
	}) unless $dryrun;

	$max -= $rv;
}

