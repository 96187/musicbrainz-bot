#!/usr/bin/perl
# perl bot.pl [options]

use FindBin;
use lib "$FindBin::Bin";
use utf8;

use MusicBrainzBot;
use DBI;
use Getopt::Long;

my $username = "";
my $password = "";
my $server = "";
my $verbose = 0;
my $max = 100;
my $dryrun = 0;

GetOptions('username|u=s' => \$username, 'password|p=s' => \$password, 'server=s' => \$server, 'verbose|v' => \$verbose, 'max|m=i' => \$max, 'dryrun' => \$dryrun);

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
$bot->login() unless $dryrun;

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("
	select w.gid, wn.name
	from work w
	join work_name wn on wn.id = w.name
	where w.edits_pending = 0
	and wn.name ~* 'in [a-g]([ -](sharp|flat))? (major|minor)'
	and wn.name ~ E' Op\. ?[0-9]'
");
$sth->execute;

while (my ($mbid, $name) = $sth->fetchrow()) {
	unless ($max > 0) {
		print "Reached maximum number of files.\n";
		last;
	}

	my $newname = $name;
	$newname =~ s/(?<!:) No\. ?([0-9])/ no. $1/g;
	$newname =~ s/(?<!:) Op\. ?([0-9])/ op. $1/g;

	$newname =~ s/ in ([A-G])[ -][Ss]harp / in $1-sharp /g;
	$newname =~ s/ in ([A-G])[ -][Ff]lat / in $1-flat /g;
	$newname =~ s/ in ([A-G](-(sharp|flat))?) [Mm]ajor/ in $1 major/g;
	$newname =~ s/ in ([A-G](-(sharp|flat))?) [Mm]inor/ in $1 minor/g;

	next if $name eq $newname;

	print "Editing work $name ($mbid):\nOld: $name\nNew: $newname\n\n" if $verbose;
	my $rv = $bot->edit_work($mbid, { 'edit_note' => 'http://musicbrainz.org/doc/Style/Classical/Language/English', 'name' => $newname }) unless $dryrun;
	$max -= $rv;
}

