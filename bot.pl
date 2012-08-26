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
		# no Georgia, otherwise all the US states + DC
		$comment =~ s/([,:] )(Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|District of Columbia|Florida|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming)$/$1$2, USA/;
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
		my $states = {
			Alabama                => 'AL',
			Alaska                 => 'AK',
			Arizona                => 'AZ',
			Arkansas               => 'AR',
			California             => 'CA',
			Colorado               => 'CO',
			Connecticut            => 'CT',
			Delaware               => 'DE',
			'District of Columbia' => 'DC',
			Florida                => 'FL',
			Georgia                => 'GA',
			Hawaii                 => 'HI',
			Idaho                  => 'ID',
			Illinois               => 'IL',
			Indiana                => 'IN',
			Iowa                   => 'IA',
			Kansas                 => 'KS',
			Kentucky               => 'KY',
			Louisiana              => 'LA',
			Maine                  => 'ME',
			Maryland               => 'MD',
			Massachusetts          => 'MA',
			Michigan               => 'MI',
			Minnesota              => 'MN',
			Mississippi            => 'MS',
			Missouri               => 'MO',
			Montana                => 'MT',
			Nebraska               => 'NE',
			Nevada                 => 'NV',
			'New Hampshire'        => 'NH',
			'New Jersey'           => 'NJ',
			'New Mexico'           => 'NM',
			'New York'             => 'NY',
			'North Carolina'       => 'NC',
			'North Dakota'         => 'ND',
			Ohio                   => 'OH',
			Oklahoma               => 'OK',
			Oregon                 => 'OR',
			Pennsylvania           => 'PA',
			'Rhode Island'         => 'RI',
			'South Carolina'       => 'SC',
			'South Dakota'         => 'SD',
			Tennessee              => 'TN',
			Texas                  => 'TX',
			Utah                   => 'UT',
			Vermont                => 'VT',
			Virginia               => 'VA',
			Washington             => 'WA',
			'West Virginia'        => 'WV',
			Wisconsin              => 'WI',
			Wyoming                => 'WY'
		};

		my $tmp = $comment;
		$comment =~ s/([,:] )(Alabama|Alaska|Arizona|Arkansas|California|Colorado|Connecticut|Delaware|District of Columbia|Florida|Georgia|Hawaii|Idaho|Illinois|Indiana|Iowa|Kansas|Kentucky|Louisiana|Maine|Maryland|Massachusetts|Michigan|Minnesota|Mississippi|Missouri|Montana|Nebraska|Nevada|New Hampshire|New Jersey|New Mexico|New York|North Carolina|North Dakota|Ohio|Oklahoma|Oregon|Pennsylvania|Rhode Island|South Carolina|South Dakota|Tennessee|Texas|Utah|Vermont|Virginia|Washington|West Virginia|Wisconsin|Wyoming), USA$/$1$states->{$2}, USA/;

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

