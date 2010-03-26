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
# Grab the GCC package build logs from the Symbian build publishing machine
# NB. This doesn't do the HTTP access, so it only works inside the Symbian network

use strict;
use Getopt::Long;

my @failures_files = ();
my $line;

while ($line =<>)
	{
	# <tr><td>adaptation/beagleboard</td><td><span style='background-color:red'>R</span> <a href='http://developer.symbian.org/main/source/packages/package/build_details.php?id=4576'>beagleboard_CompilerCompatibility.007</a><br/><span style='font-size:small'>(gcce4_4_1)</span><br/><span style='font-size:small'>2010-03-16 20:15:26</span></td><td><span style='background-color:red'>R</span> <a href='http://developer.symbian.org/main/source/packages/package/build_details.php?id=4197'>beagleboard_CompilerCompatibility.003</a><br/><span style='font-size:small'>(gcce4_4_1)</span><br/><span style='font-size:small'>2010-03-11 18:11:05</span></td><td>-</td><td>-</td><td>-</td><td>-</td></tr>

	if ($line =~/^<tr><td>([^<]+)<\/td><td>.*?>([^<]+)<\/a>/)
		{
		my $layer_package = $1;
		my $buildname = $2;
		
		my ($layer,$package) = split /\//, $layer_package;
		
		my $location = sprintf "SF_builds/%s/builds/CompilerCompatibility/%s/html/%s_%s_failures.html", $package, $buildname, $layer, $package;
		
		my $url = "http://cdn.symbian.org/" . $location;
		my $unc = "//v800020/" . $location;
		
		print "$layer_package, $buildname, $location\n";
		if (-f $unc)
			{
			open FILE, "<$unc" or die("Cannot open $unc: $!\n");
			my @html = <FILE>;
			close FILE;
			print @html;
			}
		}
	}