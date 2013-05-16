#!/usr/bin/perl
# perl bot.pl [options]

use FindBin;
use lib "$FindBin::Bin";
use utf8;

use MusicBrainzBot;

my $username = "";
my $password = "";
my $server = "test.musicbrainz.org";
my $verbose = 1;
my $max = 100;
my $dryrun = 0;

my $bot = MusicBrainzBot->new({ username => $username, password => $password, server => $server, note => $note, verbose => $verbose });
$bot->login();

my $time = gmtime;

my $mbid = $bot->add_artist({ name => "Test Artist Name $time", sort_name => 'Test Artist Sort Name', comment => 'test comment', type_id => 3, gender_id => 3, country_id => 8, 'begin_date.year' => '1900', 'begin_date.month' => 1, 'begin_date.day' => 2, 'end_date.year' => 1990, 'end_date.month' => 3, 'end_date.day' => 4, edit_note => 'test edit note' });
if ($mbid) {
	print "Successfully added artist\n";
	my $rv = $bot->edit_artist($mbid, { name => "New Test Artist Name $time", sort_name => 'New Test Artist Sort Name', comment => 'new test comment', type_id => 1, gender_id => 2, country_id => 240, 'begin_date.year' => '1999', 'begin_date.month' => 5, 'begin_date.day' => 6, 'end_date.year' => 2001, 'end_date.month' => 7, 'end_date.day' => 8, edit_note => 'new test edit note' });
	print "Successfully edited artist\n" if $rv;
}

my $mbid = $bot->add_area({ name => "Test Area Name $time", sort_name => 'Test Area Sort Name', comment => 'test comment', type_id => 1, 'begin_date.year' => '1900', 'begin_date.month' => 1, 'begin_date.day' => 2, 'end_date.year' => 1990, 'end_date.month' => 3, 'end_date.day' => 4, edit_note => 'test edit note' });
if ($mbid) {
	print "Successfully added area\n";
	my $rv = $bot->edit_area($mbid, { name => "New Test Area Name $time", sort_name => 'New Test Area Sort Name', comment => 'new test comment', type_id => 1, 'begin_date.year' => '1999', 'begin_date.month' => 5, 'begin_date.day' => 6, 'end_date.year' => 2001, 'end_date.month' => 7, 'end_date.day' => 8, edit_note => 'new test edit note' });
}

print "$rv\n";

