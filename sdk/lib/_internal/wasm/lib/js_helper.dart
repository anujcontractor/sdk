// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Helpers for working with JS.
library dart._js_helper;

import 'dart:_internal';
import 'dart:_js_annotations' as js;
import 'dart:collection';
import 'dart:typed_data';
import 'dart:wasm';

part 'regexp_helper.dart';

/// [JSValue] is the root of the JS interop object hierarchy.
class JSValue {
  final WasmExternRef _ref;

  JSValue(this._ref);

  // Currently we always explicitly box JS ref's in [JSValue] objects. In the
  // future, we will want to leave these values unboxed when possible, even when
  // they are nullable.
  static JSValue? box(WasmExternRef? ref) =>
      isDartNull(ref) ? null : JSValue(ref!);

  static WasmExternRef? unbox(JSValue? v) => v == null ? null : v._ref;

  @override
  bool operator ==(Object that) =>
      that is JSValue && areEqualInJS(_ref, that._ref);

  // Because [JSValue] is a subtype of [Object] it can be used in Dart
  // collections. Unfortunately, JS does not expose an efficient hash code
  // operation. To avoid surprising behavior, we force all [JSValue]s to fall
  // back to differentiation via equality, essentially making [Set] and [Map]
  // a regular linked list when the keys are [JSValue]. This behavior is not
  // intuitive.
  // TODO(joshualitt): There are a lot of different directions we can go, but
  // the most straightforward to to expose `JSMap` and `JSSet` from JS for users
  // who need to efficiently manage JS objects in collections.
  @override
  int get hashCode => 0;

  @override
  String toString() => stringify(_ref);

  // Overrides to avoid using [ObjectToJS].
  WasmExternRef toExternRef() => _ref;
  JSValue toJS() => this;
}

extension DoubleToJS on double {
  WasmExternRef toExternRef() => toJSNumber(this)!;
  JSValue toJS() => JSValue(toExternRef());
}

extension StringToJS on String {
  WasmExternRef toExternRef() => jsStringFromDartString(this)!;
  JSValue toJS() => JSValue(toExternRef());
}

extension ListOfObjectToJS on List<Object?> {
  WasmExternRef toExternRef() => jsArrayFromDartList(this)!;
  JSValue toJS() => JSValue(toExternRef());
}

extension ObjectToJS on Object {
  WasmExternRef toExternRef() => jsObjectFromDartObject(this);
  JSValue toJS() => JSValue(toExternRef());
}

// For now both `null` and `undefined` in JS map to `null` in Dart.
bool isDartNull(WasmExternRef? ref) => ref == null || isJSUndefined(ref);

/// A [JSArray] is a wrapper for a native JSArray.
@js.JS()
@js.staticInterop
class JSArray {}

extension JSArrayExtension on JSArray {
  external Object? pop();
  external Object? operator [](int index);
  external void operator []=(int index, Object? value);
  external int get length;
}

/// A [JSObject] is a wrapper for any JS object literal.
@js.JS()
@js.staticInterop
class JSObject {}

extension JSObjectExtension on JSObject {
  external Object? operator [](String key);
  external void operator []=(String key, Object? value);
}

class JSArrayIteratorAdapter<T> extends Iterator<T> {
  final JSArray array;
  int index = -1;

  JSArrayIteratorAdapter(this.array);

  @override
  bool moveNext() {
    index++;
    if (index > array.length) {
      throw 'Iterator out of bounds';
    }
    return index < array.length;
  }

  @override
  T get current => dartifyRaw(array[index]?.toExternRef()) as T;
}

/// [JSArrayIterableAdapter] lazily adapts a [JSArray] to Dart's [Iterable]
/// interface.
class JSArrayIterableAdapter<T> extends EfficientLengthIterable<T> {
  final JSArray array;

  JSArrayIterableAdapter(this.array);

  @override
  Iterator<T> get iterator => JSArrayIteratorAdapter<T>(array);

  @override
  int get length => array.length;
}

// Convert to double to avoid converting to [BigInt] in the case of int64.
WasmExternRef intToJSNumber(int i) => toJSNumber(i.toDouble())!;

WasmExternRef? getConstructorString(String constructor) =>
    getPropertyRaw(globalThisRaw(), constructor.toExternRef());

Object jsObjectToDartObject(WasmExternRef? ref) =>
    unsafeCastOpaque<Object>(ref.internalize());

WasmExternRef jsObjectFromDartObject(Object object) =>
    unsafeCastOpaque<WasmAnyRef>(object).externalize();

bool isJSUndefined(WasmExternRef? o) => JS<bool>('o => o === undefined', o);

bool isJSBoolean(WasmExternRef? o) =>
    JS<bool>("o => typeof o === 'boolean'", o);

bool isJSNumber(WasmExternRef? o) => JS<bool>("o => typeof o === 'number'", o);

bool isJSBigInt(WasmExternRef? o) => JS<bool>("o => typeof o === 'bigint'", o);

bool isJSString(WasmExternRef? o) => JS<bool>("o => typeof o === 'string'", o);

bool isJSSymbol(WasmExternRef? o) => JS<bool>("o => typeof o === 'symbol'", o);

bool isJSFunction(WasmExternRef? o) =>
    JS<bool>("o => typeof o === 'function'", o);

bool isJSInt8Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Int8Array", o);

bool isJSUint8Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Uint8Array", o);

bool isJSUint8ClampedArray(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Uint8ClampedArray", o);

bool isJSInt16Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Int16Array", o);

bool isJSUint16Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Uint16Array", o);

bool isJSInt32Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Int32Array", o);

bool isJSUint32Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Uint32Array", o);

bool isJSFloat32Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Float32Array", o);

bool isJSFloat64Array(WasmExternRef? o) =>
    JS<bool>("o => o instanceof Float64Array", o);

bool isJSArrayBuffer(WasmExternRef? o) =>
    JS<bool>("o => o instanceof ArrayBuffer", o);

bool isJSDataView(WasmExternRef? o) =>
    JS<bool>("o => o instanceof DataView", o);

bool isJSArray(WasmExternRef? o) => JS<bool>("o => o instanceof Array", o);

bool isJSWrappedDartFunction(WasmExternRef? o) => JS<bool>(
    "o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true",
    o);

bool isJSObject(WasmExternRef? o) => JS<bool>("o => o instanceof Object", o);

bool isJSSimpleObject(WasmExternRef? o) => JS<bool>("""o => {
            const proto = Object.getPrototypeOf(o);
            return proto === Object.prototype || proto === null;
          }""", o);

bool isJSRegExp(WasmExternRef? o) => JS<bool>("o => o instanceof RegExp", o);

bool areEqualInJS(WasmExternRef? l, WasmExternRef? r) =>
    JS<bool>("(l, r) => l === r", l, r);

// The JS runtime will run helpful conversion routines between refs and bool /
// double. In the longer term hopefully we can find a way to avoid the round
// trip.
double toDartNumber(WasmExternRef? o) => JS<double>("o => o", o);

WasmExternRef? toJSNumber(double o) => JS<WasmExternRef?>("o => o", o);

bool toDartBool(WasmExternRef? o) => JS<bool>("o => o", o);

WasmExternRef? toJSBoolean(bool b) => JS<WasmExternRef?>("b => !!b", b);

double objectLength(WasmExternRef? o) => JS<double>("o => o.length", o);

WasmExternRef? objectReadIndex(WasmExternRef? o, double index) =>
    JS<WasmExternRef?>("(o, i) => o[i]", o, index);

Object? unwrapJSWrappedDartFunction(WasmExternRef? f) =>
    JS<Object?>("f => f.dartFunction", f);

WasmExternRef? jsInt8ArrayFromDartInt8List(Int8List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Int8Array, l)', l);

WasmExternRef? jsUint8ArrayFromDartUint8List(Uint8List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Uint8Array, l)', l);

WasmExternRef? jsUint8ClampedArrayFromDartUint8ClampedList(
        Uint8ClampedList l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Uint8ClampedArray, l)', l);

WasmExternRef? jsInt16ArrayFromDartInt16List(Int16List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Int16Array, l)', l);

WasmExternRef? jsUint16ArrayFromDartUint16List(Uint16List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Uint16Array, l)', l);

WasmExternRef? jsInt32ArrayFromDartInt32List(Int32List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Int32Array, l)', l);

WasmExternRef? jsUint32ArrayFromDartUint32List(Uint32List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Uint32Array, l)', l);

WasmExternRef? jsFloat32ArrayFromDartFloat32List(Float32List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Float32Array, l)', l);

WasmExternRef? jsFloat64ArrayFromDartFloat64List(Float64List l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Float64Array, l)', l);

WasmExternRef? jsDataViewFromDartByteData(ByteData data, double length) =>
    JS<WasmExternRef?>("""(data, length) => {
          const view = new DataView(new ArrayBuffer(length));
          for (let i = 0; i < length; i++) {
              view.setUint8(i, dartInstance.exports.\$byteDataGetUint8(data, i));
          }
          return view;
        }""", data, length);

WasmExternRef? jsArrayFromDartList(List<Object?> l) =>
    JS<WasmExternRef?>('l => arrayFromDartList(Array, l)', l);

WasmExternRef? jsStringFromDartString(String s) =>
    JS<WasmExternRef?>('stringFromDartString', s);

String jsStringToDartString(WasmExternRef? s) =>
    JS<String>('stringToDartString', s);

WasmExternRef? newObjectRaw() => JS<WasmExternRef?>('() => ({})');

WasmExternRef? newArrayRaw() => JS<WasmExternRef?>('() => []');

WasmExternRef? globalThisRaw() => JS<WasmExternRef?>('() => globalThis');

WasmExternRef? callConstructorVarArgsRaw(
        WasmExternRef? o, WasmExternRef? args) =>
    // Apply bind to the constructor. We pass `null` as the first argument
    // to `bind.apply` because this is `bind`'s unused context
    // argument(`new` will explicitly create a new context).
    JS<WasmExternRef?>("""(constructor, args) => {
      const factoryFunction = constructor.bind.apply(
          constructor, [null, ...args]);
      return new factoryFunction();
    }""", o, args);

bool hasPropertyRaw(WasmExternRef? o, WasmExternRef? p) =>
    JS<bool>("(o, p) => p in o", o, p);

WasmExternRef? getPropertyRaw(WasmExternRef? o, WasmExternRef? p) =>
    JS<WasmExternRef?>("(o, p) => o[p]", o, p);

WasmExternRef? setPropertyRaw(
        WasmExternRef? o, WasmExternRef? p, WasmExternRef? v) =>
    JS<WasmExternRef?>("(o, p, v) => o[p] = v", o, p, v);

WasmExternRef? callMethodVarArgsRaw(
        WasmExternRef? o, WasmExternRef? method, WasmExternRef? args) =>
    JS<WasmExternRef?>("(o, m, a) => o[m].apply(o, a)", o, method, args);

String stringify(WasmExternRef? object) =>
    JS<String>("o => stringToDartString(String(o))", object);

void promiseThen(WasmExternRef? promise, WasmExternRef? successFunc,
        WasmExternRef? failureFunc) =>
    JS<void>("(p, s, f) => p.then(s, f)", promise, successFunc, failureFunc);

// Currently, `allowInterop` returns a Function type. This is unfortunate for
// Dart2wasm because it means arbitrary Dart functions can flow to JS util
// calls. Our only solutions is to cache every function called with
// `allowInterop` and to replace them with the wrapped variant when they flow
// to JS.
// NOTE: We are not currently replacing functions returned from JS.
Map<Function, JSValue> functionToJSWrapper = {};

WasmExternRef? jsArrayBufferFromDartByteBuffer(ByteBuffer buffer) {
  ByteData byteData = ByteData.view(buffer);
  WasmExternRef? dataView =
      jsDataViewFromDartByteData(byteData, byteData.lengthInBytes.toDouble());
  return getPropertyRaw(dataView, 'buffer'.toExternRef());
}

WasmExternRef? jsifyRaw(Object? object) {
  if (object == null) {
    return null;
  } else if (object is bool) {
    return toJSBoolean(object);
  } else if (object is Function) {
    assert(functionToJSWrapper.containsKey(object),
        'Must call `allowInterop` on functions before they flow to JS');
    return functionToJSWrapper[object]?.toExternRef();
  } else if (object is JSValue) {
    return object.toExternRef();
  } else if (object is String) {
    return jsStringFromDartString(object);
  } else if (object is Int8List) {
    return jsInt8ArrayFromDartInt8List(object);
  } else if (object is Uint8List) {
    return jsUint8ArrayFromDartUint8List(object);
  } else if (object is Uint8ClampedList) {
    return jsUint8ClampedArrayFromDartUint8ClampedList(object);
  } else if (object is Int16List) {
    return jsInt16ArrayFromDartInt16List(object);
  } else if (object is Uint16List) {
    return jsUint16ArrayFromDartUint16List(object);
  } else if (object is Int32List) {
    return jsInt32ArrayFromDartInt32List(object);
  } else if (object is Uint32List) {
    return jsUint32ArrayFromDartUint32List(object);
  } else if (object is Float32List) {
    return jsFloat32ArrayFromDartFloat32List(object);
  } else if (object is Float64List) {
    return jsFloat64ArrayFromDartFloat64List(object);
  } else if (object is ByteBuffer) {
    return jsArrayBufferFromDartByteBuffer(object);
  } else if (object is ByteData) {
    return jsDataViewFromDartByteData(object, object.lengthInBytes.toDouble());
  } else if (object is List<Object?>) {
    return jsArrayFromDartList(object);
  } else if (object is num) {
    return toJSNumber(object.toDouble());
  } else {
    return jsObjectFromDartObject(object);
  }
}

bool isWasmGCStruct(WasmExternRef ref) => ref.internalize().isObject;

Object? dartifyRaw(WasmExternRef? ref) {
  if (ref == null) {
    return null;
  } else if (isJSUndefined(ref)) {
    // TODO(joshualitt): Introduce a `JSUndefined` type.
    return null;
  } else if (isJSBoolean(ref)) {
    return toDartBool(ref);
  } else if (isJSNumber(ref)) {
    return toDartNumber(ref);
  } else if (isJSString(ref)) {
    return jsStringToDartString(ref);
  } else if (isJSInt8Array(ref)) {
    return toDartInt8List(ref);
  } else if (isJSUint8Array(ref)) {
    return toDartUint8List(ref);
  } else if (isJSUint8ClampedArray(ref)) {
    return toDartUint8ClampedList(ref);
  } else if (isJSInt16Array(ref)) {
    return toDartInt16List(ref);
  } else if (isJSUint16Array(ref)) {
    return toDartUint16List(ref);
  } else if (isJSInt32Array(ref)) {
    return toDartInt32List(ref);
  } else if (isJSUint32Array(ref)) {
    return toDartUint32List(ref);
  } else if (isJSFloat32Array(ref)) {
    return toDartFloat32List(ref);
  } else if (isJSFloat64Array(ref)) {
    return toDartFloat64List(ref);
  } else if (isJSArrayBuffer(ref)) {
    return toDartByteBuffer(ref);
  } else if (isJSDataView(ref)) {
    return toDartByteData(ref);
  } else if (isJSArray(ref)) {
    return toDartList(ref);
  } else if (isJSWrappedDartFunction(ref)) {
    return unwrapJSWrappedDartFunction(ref);
  } else if (isWasmGCStruct(ref)) {
    return jsObjectToDartObject(ref);
  } else {
    return JSValue(ref);
  }
}

Int8List toDartInt8List(WasmExternRef? ref) =>
    jsIntTypedArrayToDartIntTypedData(ref, (size) => Int8List(size))
        as Int8List;

Uint8List toDartUint8List(WasmExternRef? ref) =>
    jsIntTypedArrayToDartIntTypedData(ref, (size) => Uint8List(size))
        as Uint8List;

Uint8ClampedList toDartUint8ClampedList(WasmExternRef? ref) =>
    jsIntTypedArrayToDartIntTypedData(ref, (size) => Uint8ClampedList(size))
        as Uint8ClampedList;

Int16List toDartInt16List(WasmExternRef? ref) =>
    jsIntTypedArrayToDartIntTypedData(ref, (size) => Int16List(size))
        as Int16List;

Uint16List toDartUint16List(WasmExternRef? ref) =>
    jsIntTypedArrayToDartIntTypedData(ref, (size) => Uint16List(size))
        as Uint16List;

Int32List toDartInt32List(WasmExternRef? ref) =>
    jsIntTypedArrayToDartIntTypedData(ref, (size) => Int32List(size))
        as Int32List;

Uint32List toDartUint32List(WasmExternRef? ref) =>
    jsIntTypedArrayToDartIntTypedData(ref, (size) => Uint32List(size))
        as Uint32List;

Float32List toDartFloat32List(WasmExternRef? ref) =>
    jsFloatTypedArrayToDartFloatTypedData(ref, (size) => Float32List(size))
        as Float32List;

Float64List toDartFloat64List(WasmExternRef? ref) =>
    jsFloatTypedArrayToDartFloatTypedData(ref, (size) => Float64List(size))
        as Float64List;

ByteBuffer toDartByteBuffer(WasmExternRef? ref) =>
    toDartByteData(callConstructorVarArgsRaw(
            getConstructorString('DataView'), [JSValue.box(ref)].toExternRef()))
        .buffer;

ByteData toDartByteData(WasmExternRef? ref) {
  int length =
      toDartNumber(getPropertyRaw(ref, 'byteLength'.toExternRef())).toInt();
  ByteData data = ByteData(length);
  for (int i = 0; i < length; i++) {
    data.setUint8(
        i,
        toDartNumber(callMethodVarArgsRaw(
                ref, 'getUint8'.toExternRef(), [i].toExternRef()))
            .toInt());
  }
  return data;
}

List<double> jsFloatTypedArrayToDartFloatTypedData(
    WasmExternRef? ref, List<double> makeTypedData(int size)) {
  int length = objectLength(ref).toInt();
  List<double> list = makeTypedData(length);
  for (int i = 0; i < length; i++) {
    list[i] = toDartNumber(objectReadIndex(ref, i.toDouble()));
  }
  return list;
}

List<int> jsIntTypedArrayToDartIntTypedData(
    WasmExternRef? ref, List<int> makeTypedData(int size)) {
  int length = objectLength(ref).toInt();
  List<int> list = makeTypedData(length);
  for (int i = 0; i < length; i++) {
    list[i] = toDartNumber(objectReadIndex(ref, i.toDouble())).toInt();
  }
  return list;
}

List<Object?> toDartList(WasmExternRef? ref) => List<Object?>.generate(
    objectLength(ref).round(),
    (int n) => dartifyRaw(objectReadIndex(ref, n.toDouble())));

// These two trivial helpers are needed to work around an issue with tearing off
// functions that take / return [WasmExternRef].
bool _isDartFunctionWrapped<F extends Function>(F f) =>
    functionToJSWrapper.containsKey(f);

F _wrapDartFunction<F extends Function>(F f, WasmExternRef ref) {
  functionToJSWrapper[f] = JSValue(ref);
  return f;
}

/// Returns the JS constructor object for a given [String].
WasmExternRef? getConstructorRaw(String name) =>
    getPropertyRaw(globalThisRaw(), name.toExternRef());

/// Equivalent to `Object.keys(object)`.
JSArray objectKeys(JSObject object) => JSValue.box(callMethodVarArgsRaw(
    getConstructorRaw('Object'),
    'keys'.toExternRef(),
    [object].toExternRef())!) as JSArray;

/// Takes a [codeTemplate] string which must represent a valid JS function, and
/// a list of optional arguments. The [codeTemplate] will be inserted into the
/// JS runtime, and the call to [JS] will be replaced by a call to an external
/// static method stub that imports the JS function.
///
/// We will replace the enclosing procedure itself if:
///   1) The enclosing procedure is static.
///   2) The enclosing procedure has a body with a single statement, and that
///      statement is just the `StaticInvocation` of [JS] itself.
///   3) All of the arguments to [JS] are `VariableGet`s.
external T JS<T>(String codeTemplate,
    [arg0,
    arg1,
    arg2,
    arg3,
    arg4,
    arg5,
    arg6,
    arg7,
    arg8,
    arg9,
    arg10,
    arg11,
    arg12,
    arg13,
    arg14,
    arg51,
    arg16,
    arg17,
    arg18,
    arg19]);

/// Methods used by the wasm runtime.
@pragma("wasm:export", "\$listLength")
double _listLength(List list) => list.length.toDouble();

@pragma("wasm:export", "\$listRead")
WasmExternRef? _listRead(List<Object?> list, double index) =>
    jsifyRaw(list[index.toInt()]);

@pragma("wasm:export", "\$byteDataGetUint8")
double _byteDataGetUint8(ByteData byteData, double index) =>
    byteData.getUint8(index.toInt()).toDouble();
