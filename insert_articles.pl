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
# DROP OLD ARTICLE TABLE
# ============================================================

my $sth11d = $dbh->prepare(
    "DROP TABLE IF EXISTS article"
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
# CREATE ARTICLE TABLE
# ============================================================

my $sth11r = $dbh->prepare("
    CREATE TABLE article (
        title varchar(500),
        authid varchar(200),
        authorname varchar(1000),
        featid varchar(10),
        page varchar(50),
        volume varchar(10),
        part varchar(100),
        year varchar(10),
        month varchar(10),
        maasa varchar(500),
        samvatsara varchar(500),
        titleid varchar(150),
        PRIMARY KEY(titleid)
    )
    ENGINE=MyISAM
    CHARACTER SET utf8
    COLLATE utf8_general_ci
");

$sth11r->execute();
$sth11r->finish();

# ============================================================
# VARIABLES
# ============================================================

my $volume       = "";
my $part         = "";
my $month        = "";
my $year         = "";
my $maasa        = "";
my $samvatsara   = "";

my $title        = "";
my $feature      = "";
my $featid       = "";

my $page         = "";
my $prev_pages   = "";
my $count        = 0;

my $authids      = "";
my $author_name  = "";

my $id           = "";

# ============================================================
# READ XML
# ============================================================

my $line = <IN>;

while ($line)
{
    chomp($line);

    # ========================================================
    # VOLUME
    #
    # Example:
    #
    # <volume vnum="019">
    #
    # ========================================================

    if ($line =~ /<volume\s+vnum="([^"]+)"/)
    {
        $volume = $1;

        print "VOLUME = [$volume]\n";
    }

    # ========================================================
    # PART
    #
    # Example:
    #
    # <part pnum="01" title="ಹೊಸಕೆರೆ ಕಪಿನೀಪತಿ ಭಟ್ಟರು"
    #       month="08" year="2026"
    #       maasa="..." samvatsara="...">
    #
    # IMPORTANT:
    #
    # [^"]+
    #
    # captures ONLY the value inside pnum="..."
    #
    # ========================================================

    elsif ($line =~ /<part\b[^>]*\bpnum="([^"]+)"/)
    {
        $part = $1;

        # ----------------------------------------------------
        # MONTH
        # ----------------------------------------------------

        if ($line =~ /\bmonth="([^"]*)"/)
        {
            $month = $1;
        }
        else
        {
            $month = "";
        }

        # ----------------------------------------------------
        # YEAR
        # ----------------------------------------------------

        if ($line =~ /\byear="([^"]*)"/)
        {
            $year = $1;
        }
        else
        {
            $year = "";
        }

        # ----------------------------------------------------
        # MAASA
        # ----------------------------------------------------

        if ($line =~ /\bmaasa="([^"]*)"/)
        {
            $maasa = $1;
        }
        else
        {
            $maasa = "";
        }

        # ----------------------------------------------------
        # SAMVATSARA
        # ----------------------------------------------------

        if ($line =~ /\bsamvatsara="([^"]*)"/)
        {
            $samvatsara = $1;
        }
        else
        {
            $samvatsara = "";
        }

        # ----------------------------------------------------
        # RESET PAGE COUNTER
        # ----------------------------------------------------

        $count = 0;
        $prev_pages = "";

        print "PART = [$part]\n";
        print "MONTH = [$month]\n";
        print "YEAR = [$year]\n";
        print "MAASA = [$maasa]\n";
        print "SAMVATSARA = [$samvatsara]\n";
    }

    # ========================================================
    # TITLE
    #
    # Example:
    #
    # <title>Some title</title>
    #
    # ========================================================

    elsif ($line =~ /<title>(.*?)<\/title>/)
    {
        $title = $1;
    }

    # ========================================================
    # FEATURE
    # ========================================================

    elsif ($line =~ /<feature>(.*?)<\/feature>/)
    {
        $feature = $1;

        $featid = get_featid($feature);

        if (!defined($featid))
        {
            $featid = "";
        }
    }

    # ========================================================
    # PAGE
    # ========================================================

    elsif ($line =~ /<page>(.*?)<\/page>/)
    {
        $page = $1;

        # ----------------------------------------------------
        # Same page appearing more than once
        # ----------------------------------------------------

        if ($page eq $prev_pages)
        {
            $count++;

            $id =
                "shankara_krupa_"
                . $volume . "_"
                . $part . "_"
                . $page . "_"
                . $count;
        }
        else
        {
            $id =
                "shankara_krupa_"
                . $volume . "_"
                . $part . "_"
                . $page . "_0";

            $count = 0;
        }

        $prev_pages = $page;
    }

    # ========================================================
    # AUTHOR
    #
    # Example:
    #
    # <author type="..." title="...">Author Name</author>
    #
    # ========================================================

    elsif ($line =~ /<author\b[^>]*>(.*?)<\/author>/)
    {
    my $authorname = $1;

    print "ARTICLE AUTHOR FOUND = [$authorname]\n";

    my $aid = get_authid($authorname);

    if (defined($aid) && $aid ne "")
    {
        $authids = $authids . ";" . $aid;

        print "AUTHOR ID FOUND = [$aid]\n";
    }
    else
    {
        print "WARNING: AUTHOR NOT FOUND = [$authorname]\n";
    }

    $author_name = $author_name . ";" . $authorname;
    }

    # ========================================================
    # NO AUTHORS
    #
    # ========================================================

    elsif ($line =~ /<allauthors\s*\/>/)
    {
        $authids = "0";
        $author_name = "";
    }

    # ========================================================
    # END OF ENTRY
    # ========================================================

    elsif ($line =~ /<\/entry>/)
    {
        insert_article(
            $title,
            $authids,
            $author_name,
            $featid,
            $page,
            $volume,
            $part,
            $year,
            $month,
            $maasa,
            $samvatsara,
            $id
        );

        # ----------------------------------------------------
        # Reset entry variables
        # ----------------------------------------------------

        $title       = "";
        $authids     = "";
        $author_name = "";
        $featid      = "";
        $id          = "";
        $page        = "";
    }

    $line = <IN>;
}

# ============================================================
# CLOSE FILE / DATABASE
# ============================================================

close(IN);

$dbh->disconnect();

# ============================================================
# INSERT ARTICLE
# ============================================================

sub insert_article
{
    my (
        $title,
        $authids,
        $author_name,
        $featid,
        $page,
        $volume,
        $part,
        $year,
        $month,
        $maasa,
        $samvatsara,
        $id
    ) = @_;

    # --------------------------------------------------------
    # Remove leading semicolon
    # --------------------------------------------------------

    $authids =~ s/^;//;
    $author_name =~ s/^;//;

    # --------------------------------------------------------
    # Debug output
    # --------------------------------------------------------

    print "INSERT: ";
    print "volume=[$volume] ";
    print "part=[$part] ";
    print "page=[$page] ";
    print "title=[$title]\n";

    # --------------------------------------------------------
    # Check for empty part
    # --------------------------------------------------------

    if ($part eq "")
    {
        warn "WARNING: Empty part for volume [$volume]\n";
    }

    # --------------------------------------------------------
    # Insert using prepared statement
    # --------------------------------------------------------

    my $sth1 = $dbh->prepare("
        INSERT INTO article
        (
            title,
            authid,
            authorname,
            featid,
            page,
            volume,
            part,
            year,
            month,
            maasa,
            samvatsara,
            titleid
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    $sth1->execute(
        $title,
        $authids,
        $author_name,
        $featid,
        $page,
        $volume,
        $part,
        $year,
        $month,
        $maasa,
        $samvatsara,
        $id
    );

    $sth1->finish();
}

# ============================================================
# GET AUTHOR ID
# ============================================================

sub get_authid
{
    my ($authorname) = @_;

    my $sth = $dbh->prepare(
        "SELECT authid FROM author WHERE authorname=?"
    );

    $sth->execute($authorname);

    my $ref = $sth->fetchrow_hashref();

    my $authid = "";

    if ($ref && defined($ref->{'authid'}))
    {
        $authid = $ref->{'authid'};
    }

    $sth->finish();

    return $authid;
}

# ============================================================
# GET FEATURE ID
# ============================================================

sub get_featid
{
    my ($feature) = @_;

    my $sth = $dbh->prepare(
        "SELECT featid FROM feature WHERE feat_name=?"
    );

    $sth->execute($feature);

    my $ref = $sth->fetchrow_hashref();

    my $featid = "";

    if ($ref && defined($ref->{'featid'}))
    {
        $featid = $ref->{'featid'};
    }

    $sth->finish();

    return $featid;
}