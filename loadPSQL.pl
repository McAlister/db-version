#! /usr/bin/perl -w

################################################################################
#                                                                              #
#	Simone Aiken                                                 Dec 4, 2022   #
#                                                                              #
#   This script takes a path to a migration folder with files in the format    #
#   specfied in the readme.MD and loads them into the provided database.       #
#   It provides DB versioning using a version table compatible with the flyway #
#   java DB versioning tool for easy conversion from perl to java.             #
#                                                                              #
################################################################################
# Flyway Reference: https://flywaydb.org/documentation/getstarted/how

	use strict;
	use DBI;
	use DBD::Pg;
	#use String::CRC32;
	use File::Find;
	use Data::Dumper;

	my $self = `whoami`;

	my ($host, $port, $dbname, $user, $pass, $alterPath, $dataPath);
	&usage();

	my $dbh = &connect();
	my $currentVersion = &getCurrentVersion();

	# Getting the ordered list of sql files to run from disk.
	my %fileHash = ();
	my @fileList;
	&buildFileList();

	# Read the versions out of the Schema Table to validate with existing alters.
	my $versionHandle = $dbh->prepare("Select * from flyway_schema_history order by installed_rank");
	$versionHandle->execute();
    while(my $row = $versionHandle->fetchrow_hashref) {
        say "\t@data";
    }
	$versionHandle->finish();
	
	# Execute the remaining alters and test data sets. 
	my $timeStamp;
	for my $alterFile (@fileList) {

		open FILE, "$alterFile";
		print "\tLoading $alterFile ... ";
		my @lines = <FILE>;
		my $sql = join "", @lines;

		&initSchemaHistory($alterFile);

		$dbh->do($sql) or die "ERROR: $!\n\n";
		
		&updateSchemaHistory($alterFile);

		$dbh->commit() or die "ERROR: $!\n\n";
		print "OK\n";
	}

	# Clean up
	$dbh->close();

	exit 0;


###############################  Functions  #################################

sub usage() {

	if ( $ENV{PGHOST} ) {
		$host = $ENV{PGHOST};
	} else {
		$host = 'localhost';
	}

	if ( $ENV{PGPORT} ) {
		$port = $ENV{PGPORT};
	} else {
		$port = 5432;
	}
	
	if ( $ENV{PGDATABASE} ) {
		$dbname = $ENV{PGDATABASE};
	} else {
		die "\n\n\tthe PGDATABASE environment variable was not defined\n";
	}
	
	if ( $ENV{PGUSER} ) {
		$user = $ENV{PGUSER};
	} else {
		die "\n\n\tthe PGUSER environment variable was not defined\n";
	}
	
	if ( $ENV{PGPASSWORD} ) {
		$pass = $ENV{PGPASSWORD};
	} else {
		die "\n\n\tThe PGPASSWORD environment variable was not defined\n";
	}
	
	for ( my $i = 0 ; $i < @ARGV ; $i++ ) {
		
		if ( $ARGV[$i] eq "--alterPath" ) {
			$i++;
			$alterPath = $ARGV[$i];
			unless (-d $alterPath) { die "\n\n\t$alterPath is not a directory.\n\n"; };
			next; 
		}

		if ( $ARGV[$i] eq "--dataPath" ) {
			$i++;
			$dataPath = $ARGV[$i];
			unless (-d $dataPath) { die "\n\n\t$dataPath is not a directory.\n\n"; };
			next; 
		}

		print "\n\n\t$ARGV[$i] is not a recognized parameter\n";
		print "\tUsage: loadPSQL.pl --alterPath ./sample/alters [--dataPath ./sample/data\n\n";
		exit 1;
	}

	unless ($alterPath) { 
		print "\n\n\tUsage: loadPSQL.pl --alterPath ./sample/alters [--dataPath ./sample/data\n";
		die "\tYou must specify an --alterPath\n\n"; 
	}
}

sub connect() {

	my $dbh = DBI -> connect("dbi:Pg:dbname=$dbname;host=$host;port=$port",  
                            $user, $pass, {AutoCommit => 0, RaiseError => 1}
                         ) or die $DBI::errstr;

	return $dbh;
}

sub getCurrentVersion() {

	&createVersionTableIfNotExists();
	
	my $sql = "Select version from flyway_schema_history "
		. "Where installed_rank = (Select max(installed_rank) from flyway_schema_history)";

	my $qh = $dbh->prepare($sql);
	$qh->execute();

	my $version;
	if (($version) = $qh->fetchrow()) {
		print "\n\nCurrent Version is ... $version\n";
    } else {
		print "\n\nCurrent Version is ... N/A\n";
	}

	$qh->finish();
	return $version;
}

sub createVersionTableIfNotExists() {

	my $sql = "Select count(*) from information_schema.tables Where table_name = 'flyway_schema_history'";

	my $qh = $dbh->prepare($sql);
	$qh->execute();
	my ($count) = $qh->fetchrow_array;
   	$qh->finish();

	unless ( $count == 1 ) {

		$sql = "Create Table flyway_schema_history( "
			. "    installed_rank serial primary_key, "
			. "    version varchar(32) not null, "
			. "    description varchar(128) not null, "
            . "    type varchar(16) not null, "
            . "    script varchar(150) not null, "
            . "    checksum integer not null, "
            . "    installed_by varchar(32) not null, "
            . "    installed_on date not null default current_date, "
            . "    execution_time integer not null, "
            . "    success boolean not null"
            . ") ";

		$dbh->do($sql) or die "\n\n\tCould not create db versioning table.\n\n";
		$dbh->commit or die "\n\n\tCould not commit db version table creation.\n\n";
	}
}

# This slurps all the .sql files out of the alter and data dirs and puts them into a 
# megahash based on their version numbers.  It nests out to 4 levels X.X.X.X.
# we then flatten that into an array that is ordered by how we should run the alters.
sub buildFileList() {

	my @dirList;
	push(@dirList, $alterPath);
	if ( $dataPath ) {
		push(@dirList, $dataPath);
	}

	find(\&processFileName, @dirList);
	#print Dumper(\%fileHash);
	
	&traverseHash(\%fileHash);
	#print Dumper(\@fileList);
}

sub traverseHash() {

	my $hashRef = shift;

	if ( defined $hashRef->{file} ) {
		push(@fileList, $hashRef->{file});
		delete $hashRef->{file};
	}

	foreach my $key (sort { $a <=> $b} keys %$hashRef) {
		if ( $key eq "file" ) {
			next;
		} else {
			&traverseHash($hashRef->{$key});
		}	
	}
}

sub processFileName() {

	my $file = $File::Find::name;

	my $currentHash = \%fileHash;
	if ( $file =~ /.*\.sql$/i ) {

		if ( $file =~ /.*\/V(.*?)__.*/ ) {
			
			my $version = $1;
			my @components = split /\./, $version;
			for ( my $i = 0 ; $i < @components ; $i++ ) {
				
				unless (defined $currentHash->{$components[$i]}) {
					my %newHash = ();
					$currentHash->{$components[$i]} = \%newHash;
				}

				$currentHash = $currentHash->{$components[$i]};
			}
		
			if ( defined $currentHash->{file} ) {
				die "\n\n\tThere are two files with version $version ( $file, $currentHash->{file}\n\n";
			}
			$currentHash->{file} = $file;
		} else {
			die "\n\n\t$file is not a valid name.  See readme.md\n\n";
		}
	}
}

sub initSchemaHistory() {

	my $filePath = shift;

	if ( $filePath =~ /.*\/V(.*?)__(.*)\.[sS][qQ][lL]$/ ) {
		
		my $version = $1;
		my $description = $2;
		my $script = "V$version__$description.sql";

		my $insert = "Insert Into flyway_schema_history "
			. "(version, description, type, script, checksum, installed_by, execution_time, success) "
			. "Values (?, ?, 'sql', ?, ?, '$self', 0, false)"
	}

	$dbh->commit();
}

sub updateSchemaHistory() {

	my $file = shift;
	$dbh->do("Update flyway_schema_history set success = true Where script = '$file'" );
}
