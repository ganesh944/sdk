// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.6

// This has been automatically generated by script
// "async_nested_test_generator.dart".

import 'dart:async';

void main() async {
  String expected = "1 2 3 4 5 6 7 8 9 10";
  Node node = new Node('1', [
    new Node('2', []),
    await new Future.value(new Node('3', [
      await new Future.value(new Node('4', [
        new Node('5', [
          await new Future.value(new Node('6', [
            await new Future.value(new Node('7', [])),
          ])),
          await new Future.value(new Node('8', [])),
          await new Future.value(new Node('9', [])),
        ]),
      ])),
    ])),
    await new Future.value(new Node('10', [])),
  ]);
  String actual = node.toSimpleString();
  print(actual);
  if (actual != expected) {
    throw "Expected '$expected' but got '$actual'";
  }
}

class Node {
  final List<Node> nested;
  final String name;

  Node(this.name, [this.nested]) {}

  String toString() => '<$name:[${nested?.join(', ')}]>';

  toSimpleString() {
    var tmp = nested?.map((child) => child.toSimpleString());
    return '$name ${tmp?.join(' ')}'.trim();
  }
}
