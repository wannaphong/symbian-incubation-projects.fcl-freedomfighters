// Copyright (c) 2010 Symbian Foundation Ltd.
// All rights reserved.
// This component and the accompanying materials are made available
// under the terms of the License "Eclipse Public License v1.0"
// which accompanies this distribution, and is available
// at the URL "http://www.eclipse.org/legal/epl-v10.html".
//
// Initial Contributors:
// Symbian Foundation - Initial contribution
// 
// Description:
// Examples of things which GCC does not like in the Symbian codebase.
// See the corresponding file in "after" for the preferred way to do it

// Over-qualified class names

#include "example_classes.h"

TClass1::TClass1(int a, int b)
	: iA(a), iB(b)
	{}

int TClass1::Average()
	{
	return (iA+iB)/2;
	}

int helper1(int a)
	{
	TClass1 c(a,11);
	return c.Average();
	}


//-------------------------
// Helper function to avoid things being optimised away
int source1(void)
	{
	extern int unknown(void);
	return helper1(unknown());
	}
