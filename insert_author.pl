#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use DBI();

# ============================================================
# DATABASE PARAMETERS
# ============================================================

my $host = $ARGV[0];
my $db   = $ARGV[1];
my $usr  = $ARGV[2];
my $pwd  = $ARGV[3];

# ============================================================
# OPEN XML
# ============================================================

open(IN, "<:utf8", "hckbhatta.xml")
    or die "Can't open hckbhatta.xml\n";

# ============================================================
# DATABASE CONNECTION
# ============================================================

my $dbh = DBI->connect(
    "DBI:mysql:database=$db;host=$host",
    $usr,
    $pwd,
    {
        RaiseError => 1,
        AutoCommit => 1,
        mysql_enable_utf8 => 1
    }
) or die "Cannot connect to database\n";

# ============================================================
# DROP OLD AUTHOR TABLE
# ============================================================

my $sth11d = $dbh->prepare(
    "DROP TABLE IF EXISTS author"
);

$sth11d->execute();
$sth11d->finish();

# ============================================================
# SET UTF-8
# ============================================================

my $sth_enc = $dbh->prepare(
    "SET NAMES utf8"
);

$sth_enc->execute();
$sth_enc->finish();

# ============================================================
# CREATE AUTHOR TABLE
# ============================================================

my $sth11 = $dbh->prepare("
    CREATE TABLE author (
        authorname varchar(400),
        authid int(6) auto_increment,
        PRIMARY KEY(authid)
    )
    AUTO_INCREMENT=10001
    ENGINE=MyISAM
    CHARACTER SET utf8
    COLLATE utf8_general_ci
");

$sth11->execute();
$sth11->finish();

# ============================================================
# READ XML
# ============================================================

my $line = <IN>;

while ($line)
{
    chomp($line);

    # ========================================================
    # AUTHOR
    #
    # Matches:
    #
    # <author type="..." title="...">Author Name</author>
    #
    # The important part is (.*?) after >
    # ========================================================

    if ($line =~ /<author\b[^>]*>(.*?)<\/author>/)
    {
        my $authorname = $1;

        print "AUTHOR FOUND = [$authorname]\n";

        insert_authors($authorname);
    }

    $line = <IN>;
}

close(IN);

$dbh->disconnect();

print "Author import completed.\n";


# ============================================================
# INSERT AUTHOR
# ============================================================

sub insert_authors
{
    my ($authorname) = @_;

    # --------------------------------------------------------
    # Check if author already exists
    # --------------------------------------------------------

    my $sth = $dbh->prepare(
        "SELECT authid FROM author WHERE authorname=?"
    );

    $sth->execute($authorname);

    my $ref = $sth->fetchrow_hashref();

    if (!$ref)
    {
        # ----------------------------------------------------
        # Insert author
        # ----------------------------------------------------

        my $sth1 = $dbh->prepare(
            "INSERT INTO author (authorname) VALUES (?)"
        );

        $sth1->execute($authorname);

        $sth1->finish();

        print "INSERTED = [$authorname]\n";
    }
    else
    {
        print "ALREADY EXISTS = [$authorname]\n";
    }

    $sth->finish();
}