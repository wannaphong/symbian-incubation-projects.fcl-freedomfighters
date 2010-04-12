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
	int Average();						// Removed classname
	
	private:
	int iA;
	int iB;
	};


//Use the keyword "Typename" when using an initialiser that has been Typedef'd inside a class template
//

template <class T>
class list {
	public:
	typedef unsigned int myType;
	myType setSize (unsigned int x, unsigned int y);
	};
 
template<class T>	
inline  typename list<T>::myType list<T>::setSize (unsigned int x, unsigned int y){  //This line will NOT throw the error
         return (x*y);
	};


//use \x to specify the character code directly

char* literals()
   {
   char* string = "123\x7e456";     // use \x to specify the character code directly
   return string;
   }

