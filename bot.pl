#!/usr/bin/perl
# perl bot.pl [options]

use FindBin;
use lib "$FindBin::Bin";
use utf8;

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
$bot->login() unless $dryrun;

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("select r.gid, r.comment from recording r where r.comment ~* E'^live' and r.edits_pending = 0 order by r.artist_credit asc");
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
		$comment =~ s/^live(?:,|[,:]? )([0-9-]+(:|$))/live, $1/i;
#		$comment =~ s/^live, ([0-9-]+), /live, $1: /;
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
#		$comment =~ s/([,:] )(Olympia|Casino de Paris|Palais des Sports|Bataclan|La Cigale|Bobino|Théâtre du Châtelet|Théâtre des Champs-Élysées|New Morning|Salle Pleyel), Paris$/$1$2, Paris, France/;
#		$comment =~ s/([,:] )(Zénith), (Paris|Lille|Strasbourg|Toulouse)$/$1$2, $3, France/;
		$comment =~ s/([,:] )(California|Texas|Pennsylvania|Missouri|Nevada|Tennessee|Massachusetts|Alabama|Michigan|Washington|Louisiana|North Dakota)$/$1$2, USA/;
#		$comment =~ s/([,:] )(CO|DC|FL|IA|ID|MA|MD|NJ|NV|OH|SC|WA)$/$1$2, USA/;
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
		$comment =~ s/([,:] )BE$/$1Belgium/;
		$comment =~ s/([,:] )CH$/$1Switzerland/;
		$comment =~ s/([,:] )DE$/$1Germany/;
		$comment =~ s/([,:] )DK$/$1Denmark/;
		$comment =~ s/([,:] )FR$/$1France/;
		$comment =~ s/([,:] )JP$/$1Japan/;
		$comment =~ s/([,:] )NL$/$1Netherlands/;
		$comment =~ s/([,:] )PL$/$1Poland/;
		$comment =~ s/([,:] )SE$/$1Sweden/;
		$comment =~ s/([,:] )SU$/$1Soviet Union/;
		$comment =~ s/([,:] )US$/$1USA/;
		push @notes, "Standardising country name" if $comment ne $tmp;
		$previous->{$mbid}{'country names'}++ if $comment ne $tmp;
	}

	# Standardise states
	if (!$previous->{$mbid}{'usa states'}) {
		my $tmp = $comment;
		$comment =~ s/([,:] )Alabama, USA$/$1AL, USA/;
		$comment =~ s/([,:] )California, USA$/$1CA, USA/;
		$comment =~ s/([,:] )Colorado, USA$/$1CO, USA/;
		$comment =~ s/([,:] )Connecticut, USA$/$1CT, USA/;
		$comment =~ s/([,:] )Florida, USA$/$1FL, USA/;
		$comment =~ s/([,:] )Georgia, USA$/$1GA, USA/;
		$comment =~ s/([,:] )Illinois, USA$/$1IL, USA/;
		$comment =~ s/([,:] )Indiana, USA$/$1IN, USA/;
		$comment =~ s/([,:] )Louisiana, USA$/$1LA, USA/;
		$comment =~ s/([,:] )Maryland, USA$/$1MD, USA/;
		$comment =~ s/([,:] )Massachusetts, USA$/$1MA, USA/;
		$comment =~ s/([,:] )Michigan, USA$/$1MI, USA/;
		$comment =~ s/([,:] )Minnesota, USA$/$1MN, USA/;
		$comment =~ s/([,:] )Missouri, USA$/$1MO, USA/;
		$comment =~ s/([,:] )Nevada, USA$/$1NV, USA/;
		$comment =~ s/([,:] )New Jersey, USA$/$1NJ, USA/;
		$comment =~ s/([,:] )Ohio, USA$/$1OH, USA/;
		$comment =~ s/([,:] )Oregon, USA$/$1OR, USA/;
		$comment =~ s/([,:] )Pennsylvania, USA$/$1PA, USA/;
		$comment =~ s/([,:] )Tennessee, USA$/$1TN, USA/;
		$comment =~ s/([,:] )Texas, USA$/$1TX, USA/;
		$comment =~ s/([,:] )Virginia, USA$/$1VA, USA/;
		$comment =~ s/([,:] )Washington, USA$/$1WA, USA/;
		$comment =~ s/([,:] )West Virginia, USA$/$1WV, USA/;
		$comment =~ s/([,:] )Wisconsin, USA$/$1WI, USA/;

		push @notes, "Standardise American states" if $comment ne $tmp;
		$previous->{$mbid}{'usa states'}++ if $comment ne $tmp;
	}

	next if $comment_orig eq $comment;
	print "Editing comment for $mbid:\nOld: $comment_orig\nNew: $comment\n\n" if $verbose;
	my $rv = $bot->edit_recording($mbid, { 'edit_note' => join ("\n", @notes), 'comment' => $comment, 'as_auto_editor' => 1 }) unless $dryrun;
	$max -= $rv;
}

# TODO: This file is going to get huge. Should generate a second hash of edited things which were still found and save that instead.
store $previous, 'previousdata' unless $dryrun;

#$dbh->disconnect(); # TODO: This fails when quitting if it's not finished fetching all the rows

