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
my $current_mmp = ""; 
my $saved_filename = "";
my $current_link_target;

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
my %missing_ELF_symbol;
my %missing_export;
my %excess_export;

sub handle_message($$$$$)
	{
	my ($package,$filename,$lineno,$messagetype,$message) = @_;
	
	my $generic_message = "$messagetype: $message";
	$generic_message =~ s/'offsetof'/"offsetof"/;
	$generic_message =~ s/'([^a-zA-Z])'/"\1"/g;	# don't catch ';' in next substitution
	$generic_message =~ s/['`][^']+'/XX/g;	# suppress quoted bits of the actual instance
	$generic_message =~ s/pasting ""(.*)"" and ""(.*)""/pasting XX and YY/g;	# suppress detail of "pasting" error
	
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

	my $packages = $packages_by_file{$filename};
	if (!defined $packages)
		{
		$packages_by_file{$filename} = "\t$package\t";
		$package_count_by_file{$filename} = 1;
		}
	else
		{
		if (index($packages,"\t$package\t") < 0)
			{
			$packages_by_file{$filename} .= "\t$package\t";
			$package_count_by_file{$filename} += 1;
			}
		}
	
	if (defined $files{$instance})
		{
		# already seen this one
		return;
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
	
	# <recipe ... bldinf='M:/sf/os/bt/atext/group/bld.inf' ...
	
	if ($line =~ /^<recipe/o)
		{
		if ($line =~ / bldinf='..(\S+)' mmp='..(\S+)'/)
			{
			my $bldinf = $1;
			$current_mmp = $2;
			my ($root, $sf, $layer, $package, @rest) = split /\//, $bldinf;
			$current_package = "$layer/$package";
			}
		next;
		}

	# remember context from various commands
  if (substr($line,0,1) eq "+")
  	{
		if ($line =~ /g\+\+\.exe .* -o (\S+)\.sym /oi)
			{
			$current_link_target = $1;
			next;
			}
		if ($line =~ /^elf2e32.exe .* --output=(\S+) /oi)
			{
			$current_link_target = $1;	# admittedly an E32 image file, but never mind...
			next;
			}
		}

	# M:/sf/os/kernelhwsrv/kernel/eka/drivers/soundsc/soundldd.cpp:2927: undefined reference to `__aeabi_uidiv'
  # M:/epoc32/build/rawipnif/c_6f716cf505597250/rawip_dll/armv5/udeb/rawipmcpr.o:(.rodata+0x258): undefined reference to `non-virtual thunk to CAgentMetaConnectionProvider::GetIntSettingL(TDesC16 const&, unsigned long&, ESock::MPlatsecApiExt*)'

	# M:/epoc32/include/elements/nm_interfaces.h:255: warning: dereferencing type-punned pointer will break strict-aliasing rules
	# M:/epoc32/include/f32file.h:2169: warning: invalid access to non-static data member 'TVolFormatParam::iUId'  of NULL object
	# M:/epoc32/include/f32file.h:2169: warning: (perhaps the 'offsetof' macro was used incorrectly)
	# M:/epoc32/include/comms-infras/ss_nodemessages.h:301: error: wrong number of template arguments (3, should be 4)
	# M:/epoc32/include/elements/nm_signatures.h:496: error: provided for 'template<class TSIGNATURE, int PAYLOADATTRIBOFFSET, class TATTRIBUTECREATIONPOLICY, int PAYLOADBUFFERMAXLEN> class Messages::TSignatureWithPolymorphicPayloadMetaType'
	# M:/epoc32/include/comms-infras/ss_nodemessages.h:301: error: invalid type in declaration before ';' token
	
	if ($line =~ /(^...*):(\d+|\(\S+\)): (([^:]+): )?(.*)$/)
		{
		my $filename = $1;
		my $lineno = $2;
		my $messagetype = $4;
		my $message = $5;

		$filename =~ s/^.://;		# remove drive letter
		
		$message =~ s/&amp;/&/g;
		$message =~ s/&gt;/>/g;
		$message =~ s/&lt;/</g;
		$message =~ s/&#39;/'/g;

		if ($messagetype eq "")
			{
			if ($message =~ /^undefined reference to .([^\']+).$/)
				{
				my $symbol = $1;
  			$missing_ELF_symbol{"$current_package\t$filename $lineno\t$symbol\timpacts $current_link_target"} = 1;
				$messagetype = "error";  # linker error, fall through to the rest of the processing
				}
			else
				{
				next;
				}
			}
		# Heuristic for guessing the problem file for assembler issues
		# 
		if ($filename =~ /\\TEMP\\/i)
			{
			$filename = $saved_filename;
			$lineno = 0;
			}
		else
			{
			$saved_filename = $filename;
			}
		
		if ($messagetype eq "note")
			{
			next;		# ignore notes
			}
		if ($messagetype eq "warning" && !$warnings)
			{
			next;		# ignore warnings
			}
		if ($messagetype eq "Warning" && $message =~ /No relevant classes found./)
			{
			next;		# ignore Qt code generation warnings
			}
		if ($message =~ /.*: No such file/ && !$warnings)
			{
			# next;		# ignore "no such file", as these aren't likely to be GCC-specific
			}

		handle_message($current_package,$filename,$lineno,$messagetype,$message);	
		next;
		}

  # Error: unrecognized option -mapcs

	if ($line =~ /^Error: (.*)$/)
		{
		my $message = $1;
		handle_message($current_package,$current_mmp,0,"Error",$message);	
		next;
		}
	
	# Elf2e32: Warning: New Symbol _ZN15DMMCMediaChangeC1Ei found, export(s) not yet Frozen
	# elf2e32 : Error: E1036: Symbol _ZN21CSCPParamDBControllerD0Ev,_ZN21CSCPParamDBControllerD1Ev,_ZN21CSCPParamDBControllerD2Ev Missing from ELF File : M:/epoc32/release/armv5/udeb/scpdatabase.dll.sym.
  # elf2e32 : Error: E1053: Symbol _Z24ImplementationGroupProxyRi passed through '--sysdef' option is not at the specified ordinal in the DEF file M:/sf/mw/svgt/svgtopt/svgtplugin/BWINSCW/NPSVGTPLUGINu.DEF.

	if ($line =~ /^elf2e32 ?: ([^:]+): (.*)$/oi)
		{
		my $messagetype = $1;
		my $message = $2;

		$message =~ s/&amp;/&/g;
		$message =~ s/&gt;/>/g;
		$message =~ s/&lt;/</g;
		
		if ($message =~ /E1036: Symbol (\S+) Missing from ELF File : (.*)\.sym/i)
			{
			my $symbol_list = $1;
			my $linktarget = $2;
			
			foreach my $symbol (split /,/, $symbol_list)
				{
				$missing_export{"$current_package\t???\t$symbol\timpacts $linktarget"} = 1;
	  		}
			next;	
			}	
		
		if ($message =~ /New Symbol (\S+) found, export.s. not yet Frozen/oi)
			{
			my $symbol = $1;
	  	$excess_export{"$current_package\t???\t$symbol\textra in $current_link_target"} = 1;
	  	next;
			}

    # Symbol _Z24ImplementationGroupProxyRi passed through '--sysdef' option is not at the specified ordinal in the DEF file M:/sf/mw/svgt/svgtopt/svgtplugin/BWINSCW/NPSVGTPLUGINu.DEF.
		if ($message =~ /Symbol (\S+) passed .* DEF file .:(.*)\.$/oi)
			{
			my $symbol = $1;
			my $deffile = $2;
	  	$missing_export{"$current_package\t$deffile\t$symbol\tmisplaced in $current_link_target"} = 1;
	  	next;
			}
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
my $current_packagename;
my @currentfiles;
my @bugzilla_stuff;
foreach my $file (sort keys %error_count_by_file)
	{
	my ($root, $sf, $layer, $packagename, @rest) = split /[\/\\]/, $file;
	my $package = "$sf/$layer/$packagename";
	if ($sf eq "epoc32")
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
			my $bugreport = sprintf "\"%s\",%d,\"GCC compilation issues in %s\",\"GCC_SURGE\"", $current_package, scalar @currentfiles, $current_packagename;
			$bugreport .= ",\"" . join("<br>", "Issues identified in the following source files:", @currentfiles) . "\"";
			push @bugzilla_stuff, $bugreport;
			}
		$current_package = $package;
		$current_packagename = $packagename;
		@currentfiles = ();
		}
	my $filedetails = sprintf "\t%-6d\t%s", $error_count_by_file{$file}, $file;
	push @currentfiles, $filedetails;
	}
printf "%-6d\t%s\n", scalar @currentfiles, $current_package;
print join("\n",@currentfiles);
print "\n";
my $bugreport = sprintf "\"%s\",%d,\"GCC compilation issues in %s\",\"GCC_SURGE\"", $current_package, scalar @currentfiles, $current_packagename;
$bugreport .= ',"' . join("<br>", "Issues identified in the following source files:", @currentfiles) . '"';
push @bugzilla_stuff, $bugreport;


print "\n\n====Messages by file\n";
foreach my $file ( sort keys %error_count_by_file)
	{
	my @details = split "\n", $errors_by_file{$file};
	printf "%-6d\t%s\n\t", $error_count_by_file{$file}, $file;
	print join("\n\t", @details);
	print "\n";
	}

my %visibility_summary;
print "\n\n====Visibility problems - all\n";
foreach my $problem ( sort (keys %missing_ELF_symbol, keys %missing_export, keys %excess_export))
	{
	print "$problem\n";
	my ($package,$file,$symbol,$impact) = split /\t/, $problem;
	my $key = "$symbol\t$package";
	if (!defined $visibility_summary{$key})
		{
		$visibility_summary{$key} = 0;
		}
	$visibility_summary{$key} += 1;
	}

print "\n\n====Symbol visibility problems (>1 instance)\n";
my $current_symbol = "";
my $references = 0;
my @packagelist = ();
foreach my $problem ( sort keys %visibility_summary)
	{
	my ($symbol, $package) = split /\t/, $problem;
	if ($symbol ne $current_symbol)
		{
		if ($current_symbol ne "" && $references > 1)
			{
			printf "%-6d\t%s\n", $references, $current_symbol;
			printf "\t%-6d\t%s\n", scalar @packagelist, join(", ", @packagelist);
			}
		$current_symbol = $symbol;
		$references = 0;
		@packagelist = ();
		}
	$references += $visibility_summary{$problem};
	push @packagelist, $package;
	}
if ($references > 1)
	{
	printf "%-6d\t%s\n", $references, $current_symbol;
	printf "\t%-6d\t%s\n", scalar @packagelist, join(", ", @packagelist);
	}

print "\n\n====Missing symbols causing ELF link failures\n";
foreach my $problem ( sort keys %missing_ELF_symbol)
	{
	print "$problem\n";
	}


my @simple_exports = ();
my @vague_exports = ();
my $last_elffile = "";
my @last_objdump = ();
foreach my $problem (sort {substr($a,-12) cmp substr($b,-12)} keys %missing_export)
	{
	my ($package,$file,$symbol,$impact) = split /\t/, $problem;
	if ($impact =~ /impacts ..\/(.*)/)
		{
		my $e32file = $1;
		my $elffile = $e32file . ".sym";
		my $objdumplist = $elffile . ".txt";
		my @instances = ();
		if (-e $elffile && $last_elffile ne $elffile)
			{
			# cache miss
			if (-e $objdumplist && -s $objdumplist > 0)
				{
				open OBJDUMPLIST, "<$objdumplist";
				@last_objdump = <OBJDUMPLIST>;
				close OBJDUMPLIST;
				}
			else
				{
				open OBJDUMP, "arm-none-symbianelf-objdump --sym $elffile |";
				@last_objdump = <OBJDUMP>;
				close OBJDUMP;
				open OBJDUMPLIST, ">$objdumplist" or print STDERR "Failed to write $objdumplist: $!\n";
				print OBJDUMPLIST @last_objdump;
				close OBJDUMPLIST;
				}
			$last_elffile = $elffile;
			}
		my $length = length($symbol);
		foreach my $line (@last_objdump)
			{
			chomp $line;
			if (substr($line,-$length) eq $symbol)
				{
				push @instances, $line;
				}
			}
		close OBJDUMP;
		
		printf STDERR "Checked %s for %s, found %d instances\n", $elffile, $symbol, scalar @instances;
		print STDERR join("\n", @instances, "");
		
		if (scalar @instances == 0)
			{
			$problem = "$package\t$elffile\t$symbol\tmissing\t$file";
			}
		if (scalar @instances == 1)
			{
			my $flags = "";
			if ($instances[0] =~ /^.{8} (.{7}) /)
				{
				$flags = " (".$1.")";
				$flags =~ s/ //g;	# throw away the spaces
				}
			if (index($instances[0], ".hidden") > 0)
				{
				$problem = "$package\t$elffile\t$symbol\thidden$flags\t$file";
				}
			else
				{
				$problem = "$package\t$elffile\t$symbol\tvisible$flags\t$file";
				}
			}
		if (scalar @instances > 1)
			{
			$problem = "$package\t$elffile\t$symbol\trepeated\t$file";
			}
		}
	if ($symbol =~ /^(_ZNK?\d|[^_]|__)/)
		{
		push @simple_exports, $problem;
		}
	else
		{
		push @vague_exports, $problem;
		}
	}
printf "\n\n====Simple exports missing from linked ELF executables - (%d)\n", scalar @simple_exports;
print join("\n", sort @simple_exports, "");
printf "\n\n====Vague linkage exports missing from linked ELF executables - (%d)\n", scalar @vague_exports;
print join("\n", sort @vague_exports, "");

@simple_exports = ();
@vague_exports = ();
foreach my $problem (keys %excess_export)
	{
	my ($package,$file,$symbol,$impact) = split /\t/, $problem;
	if ($symbol =~ /^(_ZNK?\d|_Z\d|[^_]|__)/)
		{
		push @simple_exports, $problem;
		}
	else
		{
		push @vague_exports, $problem;
		}
	}
printf "\n\n====Simple unfrozen exports found in linked ELF executables - (%d)\n", scalar @simple_exports;
print join("\n", sort @simple_exports, "");
printf "\n\n====Vague linkage unfrozen exports found in linked ELF executables - (%d)\n", scalar @vague_exports;
print join("\n", sort @vague_exports, "");


print "\n\n====Bugzilla CSV input\n";
print "\"product\",\"count\",\"short_desc\",\"keywords\",\"long_desc\"\n";
print join("\n", @bugzilla_stuff, "");

