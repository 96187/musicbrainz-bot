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
my $id = "";

GetOptions('username|u=s' => \$username, 'password|p=s' => \$password, 'server=s' => \$server, 'verbose|v' => \$verbose, 'max|m=i' => \$max, 'dryrun' => \$dryrun, 'id=s' => \$id);

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
$bot->login() unless $dryrun;

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("
        select r.gid, tn.name
        from recording r
        join track_name tn on tn.id = r.name
        join artist_credit_name acn on r.artist_credit=acn.artist_credit
        join artist a on a.id=acn.artist
        where r.edits_pending = 0
        and a.gid = ?
");
$sth->execute($id);

while (my ($mbid, $name) = $sth->fetchrow()) {
        unless ($max > 0) {
                print "Reached maximum number of files.\n";
                last;
        }

        my $newname = $name;
        $newname =~ s/(?<![:.]) No\. ?([0-9])/ no. $1/g;
        $newname =~ s/(?<!:) Op\. ?([0-9])/ op. $1/g;

        $newname =~ s/ in ([A-G])[ -][Ss]harp / in $1-sharp /g;
        $newname =~ s/ in ([A-G])[ -][Ff]lat / in $1-flat /g;
        $newname =~ s/ in ([A-G](-(sharp|flat))?) [Mm]ajor/ in $1 major/g;
        $newname =~ s/ in ([A-G](-(sharp|flat))?) [Mm]inor/ in $1 minor/g;

        next if $name eq $newname;

        print "Editing recording $name ($mbid):\nOld: $name\nNew: $newname\n\n" if $verbose;
        my $rv = $bot->edit_recording($mbid, { 'edit_note' => 'Normalising recordings for this classical conductor.', 'name' => $newname }) unless $dryrun;
        $max -= $rv;
}
