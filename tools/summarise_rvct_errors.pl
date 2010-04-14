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

my $current_package = ""; 
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
my %packages_by_file;
my %package_count_by_file;
my %missing_files;

my $linktarget = "";
my %visibility_problems;

my $line;
while ($line = <>)
	{
	# </pre>os/usb, usb_CompilerCompatibility.005, SF_builds/usb/builds/CompilerCompatibility/usb_CompilerCompatibility.005/html/os_usb_failures.html

	if ($line =~/\/html\/([^\/]+)_failures.html/)
		{
		$current_package = $1;
		$current_package =~ s/_/\//;
		next;
		}

	# Error: #5: cannot open source input file "lbs/epos_cposprivacynotifier.h":
	
	if ($line =~ /cannot open source input file (\"|&quot;)(.*)(\"|&quot)/)
		{
		my $missing_file = $2;
		my $count = $missing_files{$missing_file};
		$count = 0 if (!defined $count);
		$missing_files{$missing_file} = $count + 1;
		
		# and fall through to the rest of the processing...
		}
	# ... &#39;--soname=glxgridviewplugin{000a0000}[20000a03].dll&x39; ...
	
	if ($line =~ /--soname=(\S+)(.000a0000.)?(\S+)[&']/)
		{
		$linktarget = $1.$3;
		next;
		}

	# Error: L6410W: Symbol CGlxGridViewPluginBase::AddCommandHandlersL() with non STV_DEFAULT visibility STV_HIDDEN should be resolved statically, cannot use definition in glxgridviewpluginbase{000a0000}.dso.
  
  if ($line =~ /Error: L6410W: Symbol (.*) with .*, cannot use definition in (\S+)./)
  	{
  	my $symbol = $1;
  	my $dll = $2;
		$symbol =~ s/&amp;/&/g;
		$symbol =~ s/&gt;/>/g;
		$symbol =~ s/&lt;/</g;
  	$visibility_problems{"$current_package\t$dll:\t$symbol\timpacts $linktarget"} = 1;
  	next;
		}
	# Error: L6218E: Undefined symbol RHTTPTransaction::Session() const (referred from caldavutils.o).
	
	if ($line =~ /Error: L6218E: Undefined symbol (.*) \(referred from (\S+)\)/)
		{
		my $symbol = $1;
		my $impacted = $2;
		$symbol =~ s/&amp;/&/g;
		$symbol =~ s/&gt;/>/g;
		$symbol =~ s/&lt;/</g;
  	$visibility_problems{"$current_package\t???\t$symbol\timpacts $linktarget, $impacted"} = 1;
		next;		
		}

	# &quot;J:/sf/app/commonemail/emailservices/emailclientapi/src/emailmailbox.cpp&quot;, line 49: Warning:  #830-D: function &quot;CBase::operator new(TUint, TLeave)&quot; has no corresponding operator delete (to be called if an exception is thrown during initialization of an allocated object)
	
	if ($line =~ /^("|&quot;)(...*)("|&quot;), line (\d+): ([^:]+):\s+([^:]+): (.*)$/)
		{
		my $filename = $2;
		my $lineno = $4;
		my $messagetype = $5;
		my $message_id = $6;
		my $message = $7;
		
		if ($messagetype eq "Warning" && !$warnings)
			{
			next;		# ignore warnings
			}
		
		$filename =~ s/^.://;		# remove drive letter
		
		$message =~ s/&quot;/\"/g;
		$message =~ s/&amp;/&/g;
		$message =~ s/&gt;/>/g;
		$message =~ s/&lt;/</g;
		$message =~ s/&#39;/'/g;
		my $generic_message = "$messagetype: $message_id: $message";
		$generic_message =~ s/'offsetof'/"offsetof"/;
		$generic_message =~ s/'([^a-zA-Z])'/"\1"/g;	# don't catch ';' in next substitution
		$generic_message =~ s/\"[^\"]+\"/XX/g;	# suppress quoted bits of the actual instance
		
		if (!defined $message_ids{$generic_message})
			{
			$message_ids{$generic_message} = $message_id;
			$messages_by_id{$message_id} = $generic_message;
			$all_message_counts{$message_id} = 1;
			}
		else
			{
			$all_message_counts{$message_id} += 1;
			}
		my $instance = sprintf("%s:%d: %s-#%d", $filename, $lineno, $messagetype, $message_id);

		my $packages = $packages_by_file{$filename};
		if (!defined $packages)
			{
			$packages_by_file{$filename} = "\t$current_package\t";
			$package_count_by_file{$filename} = 1;
			}
		else
			{
			if (index($packages,"\t$current_package\t") < 0)
				{
				$packages_by_file{$filename} .= "\t$current_package\t";
				$package_count_by_file{$filename} += 1;
				}
			}
		
		if (defined $files{$instance})
			{
			# already seen this one
			next;
			}

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
				
		my $error = sprintf "%-5d: %s: %s: %s", $lineno, $messagetype, $message_id, $message;
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

print "\n\n====Packages impacted (if > 1)\n";
foreach my $file ( sort {$package_count_by_file{$b} <=> $package_count_by_file{$a}} keys %package_count_by_file)
	{
	if ($package_count_by_file{$file} < 2)
		{
		next;
		}
	my ($empty,@packages) = split /\t+/, $packages_by_file{$file};
	printf "%-6d\t%s\n\t(%s)\n",$package_count_by_file{$file}, $file, join(", ", @packages);
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

print "\n\n====Visibility problems\n";
foreach my $problem ( sort keys %visibility_problems)
	{
	print "$problem\n";
	}

print "\n\n====Missing files\n";
foreach my $file ( sort {$missing_files{$b} <=> $missing_files{$a}} keys %missing_files)
	{
	printf "%-6d\t%s\n",$missing_files{$file}, $file;
	}
