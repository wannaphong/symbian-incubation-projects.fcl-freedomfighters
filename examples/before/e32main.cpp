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
// Entrypoint for Symbian .exe, keeps the compiler & linker happy

#include <e32std.h>

// helper function for other files which need to confuse the optimiser
int unknown(void) { return 42; }

extern int source1(void);		// from source1.cpp

GLDEF_C TInt E32Main()
    {
    // Call trivial functions in other source files, to stop them being optimised away
		return source1();
		}

