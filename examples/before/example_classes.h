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


// Correct refenrencing of types defined inside a class Template
// Symptom GCC : Error: Expected initializer before ' (class name)' 

template <class T>
class list {
	public:
	typedef unsigned int myType;
	myType setSize (unsigned int x, unsigned int y);
	};
 
template<class T>	
inline  list<T>::myType list<T>::setSize (unsigned int x, unsigned int y) //This line will throw the error

	{  
         return (x*y);
	};



// Need to use  \x to specify the character code directly
char* literals()
   {
   char* string = "123£456";

   return string;
   }


