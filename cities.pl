#!/usr/bin/perl
# perl bot.pl [options]

use FindBin;
use lib "$FindBin::Bin";
use utf8;
use Data::Dumper; 
use DBI;
use Getopt::Long;
use MusicBrainzBot;
use JSON;
use LWP::Simple;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->agent("area_bot/0.1");

binmode STDOUT, ":utf8";

my $username = "area_bot";
my $password = "";
my $server = "beta.musicbrainz.org";
my $verbose = 1;
my $max = 2000;
my $dryrun = 0;
my $wikipedialt = 355;
my $wikidatalt = 358;
my $partoflt = 356;

open SETTINGS, "area_bot.json" or die;
my $settingsj = <SETTINGS>;
close SETTINGS;
my $settings = decode_json($settingsj);
$password = $settings->{"password"};

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("select area.gid, area.name, regexp_replace(url, '.*/', '') as url, area.type from area join l_area_url on entity0=area.id join url on entity1=url.id where url ~ 'wikidata' and type != 1 order by area.name");
$sth->execute;

my %mbdata = ();
while (my ($mbid, $name, $wd, $type) = $sth->fetchrow()) {
	$mbdata{$wd} = { mbid => $mbid, name => $name, type => $type };
}

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
#$bot->login();

my %seen = ();
my %types = (
	"515" => "city",
	"3957" => "town",

	"494721" => "city of Japan",
	"1059478" => "town of Japan",
	"4174776" => "village of Japan",
	"308891" => "special ward of Tokyo",
#	"137773" => "ward of Japan",
#	"1122846" => "district of Japan",
	"1145012" => "special city of Japan",
	"1137833" => "core city of Japan",
	"1749269" => "city designated by government ordinance",

	"1637706" => "city with millions of inhabitants",
	"1549591" => "Großstadt",
	"13218391" => "charter city (California)",
	"3327873" => "local municipality", # Quebec
	"22865" => "Kreisfreie stadt",
	"748149" => "prefecture-level city", # China
#	"13218382" => "charter city and county (California)",
#	"262166" => "municipality of Germany",
#	"2074737" => "municipalities of Spain",
);

my @all_ids = ();

for my $type (keys %types) {
	print STDERR "Fetching pages linked to Q$type...\n";
	my $url = "http://www.wikidata.org/w/api.php?action=query&list=backlinks&bltitle=Q$type&bllimit=500&format=json&blnamespace=0";
	fetch_ids($url, "");
}

my %ids = map { $_ => 1 } @all_ids;
my @uniq_ids = sort keys %ids;
print STDERR "Found ", scalar @uniq_ids, " pages.\n";
fetch_pages(@uniq_ids);

sub fetch_ids {
	my ($url, $cont) = @_;

	my $dataj = get("$url$cont");
	my $data = decode_json($dataj);
	sleep 1;

	# Extract page names linking to this page
	my @ids = map { $_->{title} } @{ $data->{query}->{backlinks} };
	push @all_ids, @ids;

	# There were more than 500 pages linking here, fetch some more
	if ($data->{'query-continue'}->{'backlinks'}->{'blcontinue'}) {
		my $blcont = "&blcontinue=".$data->{'query-continue'}->{'backlinks'}->{'blcontinue'};
		fetch_ids($url, $blcont);
	}
}

sub fetch_pages {
	my @ids = @_;

	while (@ids) {
		my $ids = join "|", splice @ids, 0, 50;
#		my $pagedataj = get("http://www.wikidata.org/w/api.php?action=wbgetentities&ids=$ids&format=json");
#		my $pagedata = decode_json($pagedataj);
#		sleep 1;
		my $pagedata = get_page($ids);

		# For each page ...
		for my $k (keys %{ $pagedata->{entities} }) {
			if ($max <= 0) {
				print STDERR "Reached maximum.\n";
				exit;
			}
			my $K = uc($k);

			if ($mbdata{$K}) {
#				print "City $K already in MusicBrainz.\n";
				next;
			}

			my $q = $pagedata->{entities}->{$k};
			my $wp = $q->{sitelinks}->{enwiki}->{title};
			my $name = $q->{labels}->{en}->{value};
			my $wd = "http://www.wikidata.org/wiki/$K";

			# Check that P31 (instance of) or P132 (type of subdivision) is one of the acceptable types, e.g. Q515 (city)
			my $type = join "|", keys %types;
			next unless grep /^($type)$/, map { $_->{mainsnak}->{datavalue}->{value}->{'numeric-id'} } @{ $q->{claims}->{p31} }, @{ $q->{claims}->{p132} };

			# Get the parent administrative division
			my $parent = get_admin_parent($q);
			if (!$parent) {
#				print "No parent for $k, skipping.\n";
				next;
			}
			$parent = "Q$parent";

			if (!$mbdata{$parent}) {
				print "One parent not in MusicBrainz for $K: $parent\n";
			#	my $parent = get_page($parent);
				next;
			}

			if (!$name) {
				print "$K has no name\n";
				next;
			}
			print "$K\t$name\thas parent\t$parent\t$mbdata{$parent}{'name'}\n";

			next if $dryrun;
			next if $parent eq "Q21" or $parent eq "Q22"; # Skip England and Scotland

			if (in_mb($K)) {
				print "$K already used in an URL in MusicBrainz.\n";
				next;
			}

			my $mbid = $bot->add_area({
				name => $name,
				sort_name => $name,
				type_id => 3,
				edit_note => 'Importing cities from Wikidata.'
			});
			if ($mbid) {
				print "Successfully added area\n";

				my $wp2 = $wp;
				$wp2 =~ s/ /_/g;
#				$wp2 =~ s/%20/_/g;
				my $rv = $bot->add_url_relationship($mbid, "area", {
					'link_type_id' => $wikipedialt,
					url => "http://en.wikipedia.org/wiki/$wp2",
					"as_auto_editor" => 1
				}) if $wp;
				# TODO: Test whether the edit worked
		
				my $rv = $bot->add_url_relationship($mbid, "area", {
					'link_type_id' => $wikidatalt,
					url => $wd,
					"as_auto_editor" => 1
				}) if $wd;
				# TODO: Test whether the edit worked
			
				$bot->add_relationship($mbdata{$parent}->{mbid}, $mbid, "area", "area", {
					"link_type_id" => $partoflt,
					"as_auto_editor" => 1
				});
				# TODO: Test whether the edit worked
			
			}
			$max--;
		}
	}


}

sub get_admin_parent {
	my ($q) = shift;

	my @parents = map { $_->{mainsnak}->{datavalue}->{value}->{'numeric-id'} } @{ $q->{claims}->{p131} }; # is in administrative unit
	my @i = sort grep { $mbdata{"Q$_"} } @parents;
	if (@i && scalar @i > 1) {
		print "Too many parents in MusicBrainz for $q->{title}: ", join ("; ", @i), "\n";
		return "";
	} elsif (!@i && scalar @parents > 1) { # TODO: Check the parents for parents
		print "Too many parents and none in MusicBrainz for $q->{title}: ", join ("; ", @parents), "\n";
		return "";
	}
	my $parent = shift @i;
	$parent = shift @parents unless $parent;

	if (defined $seen{"Q$parent"}) {
		return $seen{"Q$parent"};
	} elsif ($parent && !$mbdata{"Q$parent"}) {
		$seen{"Q$parent"} = ""; # Mark this as seen with no known parent in case of infinite loops
		my $pagedata = get_page("Q$parent");

		# For each page ...
		for my $k (keys %{ $pagedata->{entities} }) {
			my $q = $pagedata->{entities}->{$k};
			$parent = get_admin_parent($q);
		}

		# Remember the parent we did/didn't find for later requests
		$seen{"Q$parent"} = $parent;
	}
	return $parent;
}

sub get_page {
	my ($ids) = shift;

	my $pagedataj = get("http://www.wikidata.org/w/api.php?action=wbgetentities&ids=$ids&format=json");
	my $pagedata = decode_json($pagedataj);
	sleep 1;

	return $pagedata;
}


sub in_mb {
	my $qid = shift;

	my $url = "https://beta.musicbrainz.org/ws/2/url?resource=http://www.wikidata.org/wiki/$qid&inc=area-rels&fmt=json";
	print "$url\n";
	my $r = $ua->get($url);
	sleep 1;
	if ($r->code eq "404") {
		return 0;
	} else {
		return 1;
	}

#	my $data = decode_json($r->content); 
#	if ($data->{'resource'}) {
#		print "$K already in MB\n";
#	} else {
#		print "$K not in MB\n";
#	}
}

