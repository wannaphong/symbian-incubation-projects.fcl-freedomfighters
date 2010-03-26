#! perl

# Copyright (c) 2010 Symbian Foundation Ltd
# This component and the accompanying materials are made available
# under the terms of the License "Eclipse Public License v1.0"
# which accompanies this distribution, and is available
# at the URL "http://www.eclipse.org/legal/epl-v10.html".
#
# Initial Contributors:
# Symbian Foundation Ltd - initial contribution.
# 
# Contributors:
#
# Description:
# Perl script to summarise GCC logs

use strict;
use Getopt::Long;

sub Usage($)
  {
  my ($msg) = @_;
  
  print "$msg\n\n" if ($msg ne "");
  
	print <<'EOF';
summarise_gcc_errors.pl - simple script for analysing gcc error logs
	
This script will read a collection of GCC output logs and summarise
the error messages in various useful ways.

Options:

-warnings      process warnings as well as errors
-verbose       list the files associated with each error

EOF
  exit (1);  
  }

my $warnings = 0;
my $verbose = 0;

# Analyse the rest of command-line parameters
if (!GetOptions(
    "w|warnings" => \$warnings,
    "v|verbose" => \$verbose,
    ))
  {
  Usage("Invalid argument");
  }
  
my %files;
my %errors_by_file;
my %error_count_by_file;
my %errors;
my %message_ids;
my %files_by_message_id;
my %messages_by_id;
my %unique_message_counts;
my %all_message_counts;
my $next_message_id = 1;

my $line;
while ($line = <>)
	{
	# M:/epoc32/include/elements/nm_interfaces.h:255: warning: dereferencing type-punned pointer will break strict-aliasing rules
	# M:/epoc32/include/f32file.h:2169: warning: invalid access to non-static data member 'TVolFormatParam::iUId'  of NULL object
	# M:/epoc32/include/f32file.h:2169: warning: (perhaps the 'offsetof' macro was used incorrectly)
	# M:/epoc32/include/comms-infras/ss_nodemessages.h:301: error: wrong number of template arguments (3, should be 4)
	# M:/epoc32/include/elements/nm_signatures.h:496: error: provided for 'template<class TSIGNATURE, int PAYLOADATTRIBOFFSET, class TATTRIBUTECREATIONPOLICY, int PAYLOADBUFFERMAXLEN> class Messages::TSignatureWithPolymorphicPayloadMetaType'
	# M:/epoc32/include/comms-infras/ss_nodemessages.h:301: error: invalid type in declaration before ';' token
	
	if ($line =~ /(^...*):(\d+): ([^:]+): (.*)$/)
		{
		my $filename = $1;
		my $lineno = $2;
		my $messagetype = $3;
		my $message = $4;
		
		if ($messagetype eq "note")
			{
			next;		# ignore notes
			}
		if ($messagetype eq "warning" && !$warnings)
			{
			next;		# ignore warnings
			}
		
		$filename =~ s/^.://;		# remove drive letter
		
		$message =~ s/&amp;/&/g;
		$message =~ s/&gt;/>/g;
		$message =~ s/&lt;/</g;
		$message =~ s/&#39;/'/g;
		my $generic_message = "$messagetype: $message";
		$generic_message =~ s/'offsetof'/"offsetof"/;
		$generic_message =~ s/'([^a-zA-Z])'/"\1"/g;	# don't catch ';' in next substitution
		$generic_message =~ s/['`][^']+'/XX/g;	# suppress quoted bits of the actual instance
		
		my $message_id = $next_message_id;
		if (!defined $message_ids{$generic_message})
			{
			$next_message_id++;
			$message_ids{$generic_message} = $message_id;
			$messages_by_id{$message_id} = $generic_message;
			$all_message_counts{$message_id} = 1;
			}
		else
			{
			$message_id = $message_ids{$generic_message};
			$all_message_counts{$message_id} += 1;
			}
		my $instance = sprintf("%s:%d: %s-#%d", $filename, $lineno, $messagetype, $message_id);
		
		if (defined $files{$instance})
			{
			# already seen this one
			next;
			}
		else
			{
			if (!defined $unique_message_counts{$message_id})
				{
				$unique_message_counts{$message_id} = 1;
				}
			else
				{
				$unique_message_counts{$message_id} += 1;
				}
			$files{$instance} = $message;

			if (!defined $files_by_message_id{$message_id})
				{
				$files_by_message_id{$message_id} = $filename;
				}
			else
				{
				$files_by_message_id{$message_id} .= "\n$filename";
				}
					
			my $error = sprintf "%-5d: %s: %s", $lineno, $messagetype, $message;
			if (!defined $errors_by_file{$filename})
				{
				$errors_by_file{$filename} = $error;
				$error_count_by_file{$filename} = 1;
				}
			else
				{
				$errors_by_file{$filename} .= "\n$error";
				$error_count_by_file{$filename} += 1;
				}
			}	
		next;
		}
	}

# clean up the file lists
my %filecount_by_message_id;
foreach my $id (keys %files_by_message_id)
	{
	my @longlist = split /\n/, $files_by_message_id{$id};
	my %uniq;
	foreach my $file (@longlist)
		{
		$uniq{$file} = 1;
		}
	my $uniqlist = join( "\n\t", sort keys %uniq);
	$files_by_message_id{$id} = $uniqlist;
	$filecount_by_message_id{$id} = scalar keys %uniq;
	}

print "\n\n====Occurrences of messages (distinct, all)\n";
foreach my $id ( sort {$unique_message_counts{$b} <=> $unique_message_counts{$a}} keys %unique_message_counts)
	{
	printf "%-6d\t%-6d\t%s\n", $unique_message_counts{$id}, $all_message_counts{$id}, $messages_by_id{$id};
	}

print "\n\n====Files affected per message\n";
foreach my $id ( sort {$filecount_by_message_id{$b} <=> $filecount_by_message_id{$a}} keys %filecount_by_message_id)
	{
	printf "%-6d\t%s\n", $filecount_by_message_id{$id}, $messages_by_id{$id};
	if ($verbose)
		{
		print "\t", $files_by_message_id{$id};
		}
	}

print "\n\n====Affected files by package\n";
my $current_package = "";
my @currentfiles;
foreach my $file (sort keys %error_count_by_file)
	{
	my ($root, $sf, $layer, $packagename, @rest) = split /[\/\\]/, $file;
	my $package = "$sf/$layer/$packagename";
	if ($layer eq "include")
		{
		$package = "$sf/$layer";
		}
	if ($package ne $current_package)
		{
		if ($current_package ne "")
			{
			printf "%-6d\t%s\n", scalar @currentfiles, $current_package;
			print join("\n",@currentfiles);
			print "\n";
			}
		$current_package = $package;
		@currentfiles = ();
		}
	my $filedetails = sprintf "\t%-6d\t%s", $error_count_by_file{$file}, $file;
	push @currentfiles, $filedetails;
	}
printf "%-6d\t%s\n", scalar @currentfiles, $current_package;
print join("\n",@currentfiles);
print "\n";

print "\n\n====Messages by file\n";
foreach my $file ( sort keys %error_count_by_file)
	{
	my @details = split "\n", $errors_by_file{$file};
	printf "%-6d\t%s\n\t", $error_count_by_file{$file}, $file;
	print join("\n\t", @details);
	print "\n";
	}

