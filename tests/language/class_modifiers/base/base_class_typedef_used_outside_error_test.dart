// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// SharedOptions=--enable-experiment=class-modifiers

// Error when trying to implement a typedef base class outside of
// the base class' library when the typedef is also outside the base class
// library.

import 'base_class_typedef_used_outside_lib.dart';

typedef ATypeDef = BaseClass;

class B implements ATypeDef {
//    ^
// [cfe] The class 'BaseClass' can't be implemented outside of its library because it's a base class.
//                 ^^^^^^^^
// [analyzer] COMPILE_TIME_ERROR.INVALID_USE_OF_TYPE_OUTSIDE_LIBRARY
  int foo = 1;
}
