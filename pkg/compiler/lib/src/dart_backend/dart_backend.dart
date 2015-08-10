// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_backend;

import 'dart:async' show Future;
import 'dart:math' show max;

import '../../compiler.dart' show CompilerOutputProvider;
import '../elements/elements.dart';
import '../dart2jslib.dart';
import '../dart_types.dart';
import '../diagnostic_listener.dart';
import '../compile_time_constants.dart';
import '../constants/constant_system.dart';
import '../constants/expressions.dart';
import '../constants/values.dart';
import '../enqueue.dart' show
    Enqueuer,
    ResolutionEnqueuer,
    WorldImpact;
import '../library_loader.dart' show LoadedLibraries;
import '../messages.dart' show MessageKind;
import '../mirror_renamer/mirror_renamer.dart';
import '../resolution/resolution.dart' show
    TreeElements,
    TreeElementMapping;
import '../scanner/scannerlib.dart' show
    StringToken,
    Keyword,
    OPEN_PAREN_INFO,
    CLOSE_PAREN_INFO,
    SEMICOLON_INFO,
    IDENTIFIER_INFO;
import '../tree/tree.dart';
import '../universe/universe.dart' show
    Selector,
    UniverseSelector;
import '../util/util.dart';
import 'backend_ast_to_frontend_ast.dart' as backend2frontend;

part 'backend.dart';
part 'renamer.dart';
part 'placeholder_collector.dart';
part 'outputter.dart';
