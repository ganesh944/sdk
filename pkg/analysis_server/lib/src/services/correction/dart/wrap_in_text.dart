// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/dart/abstract_producer.dart';
import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class WrapInText extends CorrectionProducer {
  ParameterElement _parameterElement;
  Expression _stringExpression;

  @override
  FixKind get fixKind => DartFixKind.WRAP_IN_TEXT;

  @override
  Future<void> compute(DartChangeBuilder builder) async {
    //
    // Extract the information needed to build the edit.
    //
    _extractContextInformation(node);
    if (_parameterElement == null || _stringExpression == null) {
      return;
    }
    if (!flutter.isWidgetType(_parameterElement.type)) {
      return;
    }

    //
    // Extract the information needed to build the edit.
    //
    var stringExpressionCode = utils.getNodeText(_stringExpression);

    //
    // Build the edit.
    //
    await builder.addFileEdit(file, (DartFileEditBuilder builder) {
      builder.addSimpleReplacement(
        range.node(_stringExpression),
        'Text($stringExpressionCode)',
      );
    });
  }

  /// Set the `String` typed named expression to [_stringExpression], and the
  /// corresponding parameter to [_parameterElement]. Leave the fields `null`
  /// if not a named argument, or not a `String` typed expression.
  void _extractContextInformation(AstNode node) {
    if (node is SimpleIdentifier) {
      var label = node.parent;
      if (label is Label) {
        var namedExpression = label.parent;
        if (namedExpression is NamedExpression) {
          var expression = namedExpression.expression;
          if (expression.staticType.isDartCoreString) {
            _parameterElement = node.staticElement;
            _stringExpression = expression;
          }
        }
      }
    }
  }
}
