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
use POSIX qw(strftime);

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->agent("area_bot/0.1");

binmode STDOUT, ":utf8";

my $username = "area_bot";
my $password = "";
my $server = "beta.musicbrainz.org";
my $verbose = 1;
my $max = 1000;
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

my $countries = ();
my $sthc = $dbh->prepare("select url, name from area a join l_area_url lau on lau.entity0=a.id join url on url.id=lau.entity1 where url ~ 'wikidata' and a.type = 1;");
$sthc->execute;
while (my ($url, $name) = $sthc->fetchrow()) {
	$url =~ s/.*\/Q//;
	$countries->{$url} = $name;
}

my $sth = $dbh->prepare("
select area.gid, area.name, regexp_replace(url, '.*/', '') as url, area.type
from area
join l_area_url on entity0=area.id
join url on entity1=url.id
where url ~ 'wikidata'
and area.gid not in ('9d5dd675-3cf4-4296-9e39-67865ebee758', '2b30f961-ed7c-40d2-a9c5-6a905b35439a', '6fa1c7da-6689-4cec-85f9-680f853e8a08', '8297708c-5743-47d6-a5ac-f40a41c49ad9')
and (
	type != 1
	or type is null
	or area.id in (
		select a.id
		from area a
		where a.type = 1
		and a.ended = 'f'
		and a.id not in (
			select entity0
			from l_area_area laa
			join area a1 on a1.id=laa.entity1
			where a1.type = 2
		)
	)
)
order by area.name
");
# select a.name from area a where a.type = 1 and a.ended = 'f' and a.id not in (select entity0 from l_area_area laa join area a1 on a1.id=laa.entity1 where a1.type = 2) order by a.name;
$sth->execute;

my %mbdata = ();
while (my ($mbid, $name, $wd, $type) = $sth->fetchrow()) {
	$mbdata{$wd} = { mbid => $mbid, name => $name, type => $type };
}

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
#$bot->login();

my %seen = ();
my %types = (
	"515" => 3, #"city",
	"3957" => 3, #"town",

	# Japan
#	"50337" => , # "prefecture of Japan"
#	"494721" => 3, #"city of Japan",
#	"1059478" => 3, #"town of Japan",
#	"4174776" => 3, #"village of Japan",
#	"308891" => 3, #"special ward of Tokyo",
#	"137773" => '', #"ward of Japan",
#	"1122846" => "district of Japan",
#	"1145012" => 3, #"special city of Japan",
#	"1137833" => 3, #"core city of Japan",
#	"1749269" => 3, #"city designated by government ordinance",

	# Taiwan
#	"706447" => , # "county"
	"2225003" => 3, # "special municipality"
	"83020" => 3, # "provincial city"
#	"705296" => , # "district of Taiwan"
	"713146" => 3, # "county-controlled city"
	"12039044" => 3, # "urban township"
	"12039539" => 3, # "rural township"
#	"12082384" => , # "urban village"
#	"12082132" => , # "rural village"


	# Vietnam
	"3249005" => 3, # "provincial city of Vietnam"

	# Norway
	"755707" => 4, # "municipality of norway"

	# China
	"748149" => 3, #"prefecture-level city", # China

	# Luxembourg
	"1146429" => 2, # cantons of Luxembourg

	# Italy
	"747074" => 4, # comune of Italy

	# France
#	"484170" => 3, # commune of France

	# Belgium
#	"493522" => 4, # municipality of Belgium

	"856076" => 4, # "municipality of finland"
	"2177636" => 4, # "municipality of denmark"
	"127448" => 4, # "municipality of sweden"

	"3327873" => 3, #"local municipality", # Quebec

	# Austria
	"13539802" => 3, # Stadtgemeinde (Kommunalrecht)
	"262882" => 3, # Statutarstad

#	"6784672" => ?, # obec # Slovakia

	"1637706" => 3, #"city with millions of inhabitants",
	"1549591" => 3, #"Großstadt",
##	"13218391" => "charter city (California)",
	"22865" => 3, #"Kreisfreie stadt",

##	"13218382" => "charter city and county (California)",
##	"262166" => "municipality of Germany",
##	"2074737" => "municipalities of Spain",
	"13218690" => 3, #"town in Hungary",
);

if ($ARGV[0] eq "villages") {
	%types = ("532" => 3);
} elsif ($ARGV[0] eq "france") {
	%types = ("484170" => 3);
	$max = 10000;
}

my @all_ids = ();
my %stats = ();

for my $type (keys %types) {
	print STDERR "Fetching pages linked to Q$type...\n";
	my $url = "http://www.wikidata.org/w/api.php?action=query&list=backlinks&bltitle=Q$type&bllimit=500&format=json&blnamespace=0";
	fetch_ids($url, "");
}

my %ids = map { $_ => 1 } @all_ids;
my @uniq_ids = sort keys %ids;
print STDERR "Found ", scalar @uniq_ids, " pages.\n";
my @notinmb  = grep { not $mbdata{uc($_)} } @uniq_ids;
print STDERR "Found ", scalar @notinmb, " pages not in MusicBrainz.\n";
#print join ";", @notinmb;
print "\n";
fetch_pages(@notinmb);
print_stats(\%stats);

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
		for my $K (keys %{ $pagedata->{entities} }) {
#			print "$k\n";
			if ($max <= 0) {
				print STDERR "Reached maximum.\n";
				exit;
			}
#			my $K = uc($k);

			if ($mbdata{$K}) {
#				print "City $K already in MusicBrainz.\n";
				next;
			}

			my $q = $pagedata->{entities}->{$K};
			my $wp = $q->{sitelinks}->{enwiki}->{title};
			my $name = $q->{labels}->{en}->{value};
			my $wd = "http://www.wikidata.org/wiki/$K";

			# Check that P31 (instance of) or P132 (type of subdivision) is one of the acceptable types, e.g. Q515 (city)
			my $type = join "|", keys %types;
			my @parents = grep /^($type)$/, map { $_->{mainsnak}->{datavalue}->{value}->{'numeric-id'} } @{ $q->{claims}->{P31} }, @{ $q->{claims}->{P132} };
#			next unless grep /^($type)$/, map { $_->{mainsnak}->{datavalue}->{value}->{'numeric-id'} } @{ $q->{claims}->{P31} }, @{ $q->{claims}->{P132} };
			if (!scalar @parents > 0) {
				$stats{"Not P31 or P132"}{$K}++;
				next;
			}
			$type = $types{ $parents[0] };

			my $country = $q->{claims}->{P17}[0]->{mainsnak}->{datavalue}->{value}->{'numeric-id'} || "no country";
			next if $country eq "794"; # Skip Iran, too many villages
			$country = $countries->{$country} if $countries->{$country};

			# Get the parent administrative division
			my $parent = get_admin_parent($q);
			if (!$parent) {
				$stats{"No parent ($country)"}{$K}++;
#				print "No parent for $k, skipping.\n";
				next;
			}
			$parent = "Q$parent";

			if (!$mbdata{$parent}) {
				$stats{"One parent not in MB"}{$K}++;
#				print "One parent not in MusicBrainz for $K: $parent\n";
			#	my $parent = get_page($parent);
				next;
			}

			if (!$name) {
				$stats{"No name"}{$K}++;
#				print "$K has no name\n";
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
				type_id => $type,
				edit_note => 'Importing cities from Wikidata.'
			});
			if ($mbid) {
#				print "Successfully added area\n";

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

	my @parents = map { $_->{mainsnak}->{datavalue}->{value}->{'numeric-id'} } @{ $q->{claims}->{P131} }; # is in administrative unit
	my @i = sort grep { $mbdata{"Q$_"} } @parents;
	if (@i && scalar @i > 1) {
		$stats{"Too many parents in MB"}{ $q->{title} }++;
#		print "Too many parents in MusicBrainz for $q->{title}: ", join ("; ", @i), "\n";
		return "";
	} elsif (!@i && scalar @parents > 1) { # TODO: Check the parents for parents
		$stats{"Too many parents and none in MB"}{ $q->{title} }++;
#		print "Too many parents and none in MusicBrainz for $q->{title}: ", join ("; ", @parents), "\n";
		return "";
	}
	my $parent = shift @i;
	$parent = shift @parents unless $parent;

	if (defined $seen{"Q$parent"}) {
#		print "seen $parent, returning ", $seen{"Q$parent"}, "\n" unless $parent eq "";
		return $seen{"Q$parent"};
	} elsif ($parent && !$mbdata{"Q$parent"}) {
#		print "temporarily marking $parent as seen with no parent\n";
		$seen{"Q$parent"} = ""; # Mark this as seen with no known parent in case of infinite loops
		my $pagedata = get_page("Q$parent");
		my $newparent = "";

		# For each page ...
		for my $k (keys %{ $pagedata->{entities} }) {
			my $q = $pagedata->{entities}->{$k};
			$newparent = get_admin_parent($q);
#			print "got parent $newparent for $parent\n";
		}

		# Remember the parent we did/didn't find for later requests
#		print "remembering parent: $newparent for $parent\n";
		$seen{"Q$parent"} = $newparent;
		$parent = $newparent;
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


sub print_stats {
	my $stats = shift;
	my $page = "";

	$page .= qq(<script src="jquery.min.js"></script>);
	$page .= strftime("%Y-%m-%d %H:%M %Z", localtime(time())) . "<br/><br/>\n";

	for my $k (sort keys %$stats) {
		my $id = $k;
		$id =~ s/[^A-Za-z0-9]//g;
		$id =~ tr/A-Z/a-z/;
		my $res = scalar keys %{ $stats->{$k} };
		my $hidden = $res > 25 ? "display:none" : "";
		$page .= qq(<div><h3 style="background-color: lightgrey">$k</h3>);
		$page .= qq($res pages \(<span style="color: blue; cursor: pointer" onclick="\$\('#$id'\).toggle\(\);">toggle</span>\)\n) if $hidden;
		$page .= qq(<ul id="$id" style="$hidden">\n);
		for my $j (sort keys %{ $stats->{$k} }) {
			$page .= qq(<li><a href="https://www.wikidata.org/wiki/$j">$j</a></li>\n);
		}
		$page .= qq(</ul></div>\n);
	}

	$page .= qq[ <script type="text/javascript"> ];
	$page .= qq[ \$("body").prepend("<ul id='menulist' style='width:400px;border: 2px solid grey'></ul>"); ];
	$page .= qq[ \$("h3").each(function(i,v){ var id = \$(v).text().replace(/\[^A-Za-z0-9\]+/g, '').toLowerCase(); \$("#menulist").append( "<li><a href='#"+id+"'>" + \$(v).text() + "</a></li>") }); ];
	$page .= qq[ </script> ];

	open FILE, ">", "/home/nikki/public_html/area_bot.html" or die;
	print FILE "$page\n";
	close FILE;

}
