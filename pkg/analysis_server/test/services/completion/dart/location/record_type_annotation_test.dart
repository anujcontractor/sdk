// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../../client/completion_driver_test.dart';
import '../completion_printer.dart' as printer;

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RecordTypeAnnotationTest);
  });
}

@reflectiveTest
class RecordTypeAnnotationTest extends AbstractCompletionDriverTest {
  @override
  TestingCompletionProtocol get protocol => TestingCompletionProtocol.version2;

  @override
  Future<void> setUp() async {
    await super.setUp();

    printerConfiguration = printer.Configuration(
      filter: (suggestion) {
        final completion = suggestion.completion;
        if (['A0', 'B0'].any(completion.startsWith)) {
          return true;
        }
        return {'buffer', 'stringBuffer'}.contains(completion);
      },
    );
  }

  Future<void> test_named_comma_space_prefix_x_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
({int foo01, A0^}) f() {}
''');

    assertResponse('''
replacement
  left: 2
suggestions
  A01
    kind: class
  A02
    kind: class
''');
  }

  Future<void> test_named_comma_space_prefix_x_space_name_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
({int foo01, A0^ foo02}) f() {}
''');

    assertResponse('''
replacement
  left: 2
suggestions
  A01
    kind: class
  A02
    kind: class
''');
  }

  Future<void> test_named_comma_space_type_space_prefix_x_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
({int foo01, StringBuffer str^}) f() {}
''');

    assertResponse('''
replacement
  left: 3
suggestions
  stringBuffer
    kind: identifier
''');
  }

  Future<void> test_named_comma_space_type_space_x_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
({int foo01, StringBuffer ^}) f() {}
''');

    assertResponse('''
suggestions
  buffer
    kind: identifier
  stringBuffer
    kind: identifier
''');
  }

  Future<void> test_named_comma_space_x_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
({int foo01, ^}) f() {}
''');

    assertResponse('''
suggestions
  A01
    kind: class
  A02
    kind: class
  B01
    kind: class
''');
  }

  Future<void> test_named_comma_space_x_space_name_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
({int foo01, ^ foo02}) f() {}
''');

    assertResponse('''
suggestions
  A01
    kind: class
  A02
    kind: class
  B01
    kind: class
''');
  }

  Future<void> test_positional_comma_space_prefix_x_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
(int, A0^) f() {}
''');

    assertResponse('''
replacement
  left: 2
suggestions
  A01
    kind: class
  A02
    kind: class
''');
  }

  Future<void> test_positional_comma_space_prefix_x_space_name_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
(int, A0^ foo) f() {}
''');

    assertResponse('''
replacement
  left: 2
suggestions
  A01
    kind: class
  A02
    kind: class
''');
  }

  Future<void> test_positional_comma_space_prefix_x_suffix_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
(int, A0^foo) f() {}
''');

    assertResponse('''
replacement
  left: 2
  right: 3
suggestions
  A01
    kind: class
  A02
    kind: class
''');
  }

  Future<void> test_positional_comma_space_x_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
(int, ^) f() {}
''');

    assertResponse('''
suggestions
  A01
    kind: class
  A02
    kind: class
  B01
    kind: class
''');
  }

  Future<void> test_positional_comma_space_x_space_name_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
(int, ^ foo) f() {}
''');

    assertResponse('''
suggestions
  A01
    kind: class
  A02
    kind: class
  B01
    kind: class
''');
  }

  Future<void> test_positional_comma_space_x_suffix_right() async {
    await computeSuggestions('''
class A01 {}
class A02 {}
class B01 {}
(int, ^foo) f() {}
''');

    assertResponse('''
replacement
  right: 3
suggestions
  A01
    kind: class
  A02
    kind: class
  B01
    kind: class
''');
  }
}
