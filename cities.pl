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

my $username = "area_bot";
my $password = "";
my $server = "test.musicbrainz.org";
$server = "beta.musicbrainz.org";
my $verbose = 1;
my $max = 2000;
my $dryrun = 0;
my $country = "";
#my $cc = "ME";
my @cc = qw();

my $wikipedialt = 355;
my $wikidatalt = 358;
my $partoflt = 356;
if ($server eq "test.musicbrainz.org") {
	$username = "nikki_bot";
	$password = "mb";
	$wikipedialt = 351;
	$wikidatalt = 354;
	$partoflt = 352;
}

my $dbh = DBI->connect('dbi:Pg:dbname=musicbrainz_db_slave', 'musicbrainz', '', { pg_enable_utf8 => 1 }) or die;
$dbh->do("SET search_path TO musicbrainz");
my $sth = $dbh->prepare("select area.gid, area.name, regexp_replace(url, '.*/', '') as url from area join l_area_url on entity0=area.id join url on entity1=url.id where url ~ 'wikidata' order by area.name");
$sth->execute;

my %mbdata = ();
while (my ($mbid, $name, $wd) = $sth->fetchrow()) {
	$mbdata{$wd} = { mbid => $mbid, name => $name };
}

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
#$bot->login();

my %seen = ();

# Q515 # city
# Q1749269 # city designated by government ordinance
# Q1637706 # city with millions of inhabitants
# Q494721 # city (Japanese subdivision thingy)
# Q1549591 # Großstadt
my $url = "http://www.wikidata.org/w/api.php?action=query&list=backlinks&bltitle=Q515&bllimit=500&format=json&blnamespace=0";

fetch_data($url, "");

sub fetch_data {
	my ($url, $cont) = @_;

	my $dataj = get("$url$cont");
	my $data = decode_json($dataj);

	# Extract page names linking to this page
	my @ids = map { $_->{title} } @{ $data->{query}->{backlinks} };

	# Can only fetch 50 pages at a time
	while (@ids) {
		my $ids = join "|", splice @ids, 0, 50;
		my $pagedataj = get("http://www.wikidata.org/w/api.php?action=wbgetentities&ids=$ids&format=json");
		my $pagedata = decode_json($pagedataj);

		# For each page ...
		for my $k (keys %{ $pagedata->{entities} }) {
			if ($max <= 0) {
				print "Reached maximum.\n";
				exit
			}
			my $K = uc($k);
			if ($mbdata{$K}) {
				print "City $K already in MusicBrainz.\n";
				next;
			}

			my $q = $pagedata->{entities}->{$k};
			my $wp = $q->{sitelinks}->{enwiki}->{title};
			my $name = $q->{labels}->{en}->{value};
			my $wd = "http://www.wikidata.org/wiki/$K";

			# Check that P31 (instance of) is Q515 (city)
			next unless grep /^515$/, map { $_->{mainsnak}->{datavalue}->{value}->{'numeric-id'} } @{ $q->{claims}->{p31} };

			# Get the parent administrative division
			my $parent = get_admin_parent($q);
			if (!$parent) {
				print "No parent for $k, skipping.\n";
				next;
			}
			$parent = "Q$parent";

			if (!$mbdata{$parent}) {
				print "Subdivision $parent not in MusicBrainz.\n"; # TODO: Try fetching parent of parent
			#	my $parent = get_page($parent);
				next;
			}


			print "$K\t$name\thas parent $parent\t$mbdata{$parent}{'name'}\n";

			my $mbid = $bot->add_area({
				name => $name,
				sort_name => $name,
				type_id => 3,
				edit_note => 'Importing cities from Wikidata.'
			});
			if ($mbid) {
				print "Successfully added area\n";
	
				my $rv = $bot->add_url_relationship($mbid, "area", {
					'link_type_id' => $wikipedialt,
					url => "http://en.wikipedia.org/wiki/$wp",
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

	# There were more than 500 pages linking here, fetch some more
	if ($data->{'query-continue'}->{'backlinks'}->{'blcontinue'}) {
		my $blcont = "&blcontinue=".$data->{'query-continue'}->{'backlinks'}->{'blcontinue'};
		fetch_data($url, $blcont);
	}
}


sub get_admin_parent {
	my ($q) = shift;

	my @i = sort map { $_->{mainsnak}->{datavalue}->{value}->{'numeric-id'} } @{ $q->{claims}->{p131} }; # is in administrative unit
	if (scalar @i > 1) {
		print "Too many parents for $q->{title}: ", join ("; ", @i), "\n";
		return "";
	}
	my $parent = shift @i;

	if ($parent && !$mbdata{"Q$parent"} && !$seen{"Q$parent"}) {
		$seen{"Q$parent"}++;
		my $pagedata = get_page("Q$parent");

		# For each page ...
		for my $k (keys %{ $pagedata->{entities} }) {
			my $q = $pagedata->{entities}->{$k};
			$parent = get_admin_parent($q);
		}
	}
	return $parent;
}

sub get_page {
	my ($ids) = shift;

	my $pagedataj = get("http://www.wikidata.org/w/api.php?action=wbgetentities&ids=$ids&format=json");
	my $pagedata = decode_json($pagedataj);

	return $pagedata;
}

