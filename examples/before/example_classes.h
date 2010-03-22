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

// Various problems with classes

class TClass1
	{
	public:
	TClass1(int a, int b);
	int TClass1::Average();			// Error! Member function name should not be qualified
	
	private:
	int iA;
	int iB;
	};
