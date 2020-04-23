// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/edit/nnbd_migration/migration_info.dart';
import 'package:analysis_server/src/edit/nnbd_migration/path_mapper.dart';
import 'package:analysis_server/src/edit/nnbd_migration/unit_renderer.dart';
import 'package:analysis_server/src/edit/nnbd_migration/web/file_details.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'nnbd_migration_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnitRendererTest);
  });
}

@reflectiveTest
class UnitRendererTest extends NnbdMigrationTestBase {
  /// Render [libraryInfo], using a [MigrationInfo] which knows only about this
  /// library.
  List<FileDetails> renderUnits() {
    var packageRoot = convertPath('/package');
    var migrationInfo =
        MigrationInfo(infos, {}, resourceProvider.pathContext, packageRoot);

    var contents = <FileDetails>[];
    for (var unitInfo in infos) {
      contents.add(
          UnitRenderer(unitInfo, migrationInfo, PathMapper(resourceProvider))
              .render());
    }
    return contents;
  }

  Future<void> test_editList_containsCount() async {
    await buildInfoForSingleTestFile('''
int a = null;
bool b = a.isEven;
''', migratedContent: '''
int? a = null;
bool  b = a!.isEven;
''');
    var output = renderUnits()[0];
    var editList = output.edits;
    expect(editList, hasLength(2));
  }

  Future<void> test_editList_containsEdits() async {
    await buildInfoForSingleTestFile('''
int a = null;
bool b = a.isEven;
''', migratedContent: '''
int? a = null;
bool  b = a!.isEven;
''');
    var output = renderUnits()[0];
    expect(output.edits, hasLength(2));
    expect(output.edits[0].line, equals(1));
    expect(output.edits[0].offset, equals(3));
    expect(output.edits[0].explanation,
        equals("Changed type 'int' to be nullable"));
    expect(output.edits[1].line, equals(2));
    expect(output.edits[1].offset, equals(26));
    expect(output.edits[1].explanation,
        equals('Added a non-null assertion to nullable expression'));
  }

  Future<void> test_handle_large_deleted_region_near_top_of_file() async {
    await buildInfoForSingleTestFile('''
class C {
  int hash(Iterable<int> elements) {
    if (elements == null) {
      return null.hashCode;
    }
    return 0;
  }
}

List<int> x = [null];
''', migratedContent: '''
class C {
  int  hash(Iterable<int >  elements) {
    if (elements == null) {
      return null.hashCode;
    }
    return 0;
  }
}

List<int?>  x = [null];
''', removeViaComments: false);
    renderUnits();
    // No assertions necessary; we are checking to make sure there is no crash.
  }

  Future<void> test_info_within_deleted_code() async {
    await buildInfoForSingleTestFile('''
class C {
  int hash(Iterable<int> elements) {
    if (elements == null) {
      return null.hashCode;
    }
    return 0;
  }
}

List<int> x = [null];
''', migratedContent: '''
class C {
  int  hash(Iterable<int >  elements) {
    if (elements == null) {
      return null.hashCode;
    }
    return 0;
  }
}

List<int?>  x = [null];
''', removeViaComments: false);
    var output = renderUnits()[0];
    // Strip out URLs and span IDs; they're not being tested here.
    var navContent = output.navigationContent
        .replaceAll(RegExp('href="[^"]*"'), 'href="..."')
        .replaceAll(RegExp('id="[^"]*"'), 'id="..."');
    expect(navContent, '''
class <span id="...">C</span> {
  <a href="..." class="nav-link">int</a>  <span id="...">hash</span>(<a href="..." class="nav-link">Iterable</a>&lt;<a href="..." class="nav-link">int</a> &gt;  <span id="...">elements</span>) {
    if (<a href="..." class="nav-link">elements</a> <a href="..." class="nav-link">==</a> null) {
      return null.<a href="..." class="nav-link">hashCode</a>;
    }
    return 0;
  }
}

<a href="..." class="nav-link">List</a>&lt;<a href="..." class="nav-link">int</a>?&gt;  <span id="...">x</span> = <span id="...">[null]</span>;
''');
  }

  Future<void> test_navContentContainsEscapedHtml() async {
    await buildInfoForSingleTestFile('List<String> a = null;',
        migratedContent: 'List<String >? a = null;');
    var output = renderUnits()[0];
    // Strip out URLs which will change; not being tested here.
    var navContent =
        output.navigationContent.replaceAll(RegExp('href=".*?"'), 'href="..."');
    expect(
        navContent,
        contains(r'<a href="..." class="nav-link">List</a>'
            r'&lt;<a href="..." class="nav-link">String</a> &gt;? '
            r'<span id="o13">a</span> = <span id="o17">null</span>;'));
  }

  Future<void> test_outputContainsModifiedAndUnmodifiedRegions() async {
    await buildInfoForSingleTestFile('int a = null;',
        migratedContent: 'int? a = null;');
    var output = renderUnits()[0];
    var regions = _stripDataAttributes(output.regions);
    expect(regions,
        contains('int<span class="region added-region">?</span> a = null;'));
  }

  Future<void> test_project_with_parts() async {
    // In this test, we migrate a library and its part file.  Both files require
    // addition of a `?`, but at different offsets.  We make sure the `?`s get
    // added at the correct locations in each file.
    var files = {
      convertPath('/project/lib/a.dart'): '''
part 'b.dart';

int f() => null;
''',
      convertPath('/project/lib/b.dart'): '''
part of 'a.dart';

int g() => null;
''',
    };
    var packageRoot = convertPath('/project');
    await buildInfoForTestFiles(files, includedRoot: packageRoot);
    var output = renderUnits();
    expect(output[0].sourceCode, contains('int?'));
    expect(output[1].sourceCode, contains('int?'));
  }

  Future<void> test_reference_to_sdk_file_with_parts() async {
    await buildInfoForSingleTestFile('''
import 'dart:async';
Future<int> f(Future<int> x) {
  return x.whenComplete(() {});
}
''', migratedContent: '''
import 'dart:async';
Future<int >  f(Future<int >  x) {
  return x.whenComplete(() {});
}
''');
    renderUnits();
    // No assertions; we're just making sure there's no crash.
  }

  Future<void> test_regionsContainsEscapedHtml_ampersand() async {
    await buildInfoForSingleTestFile('bool a = true && false;',
        migratedContent: 'bool  a = true && false;');
    var output = renderUnits()[0];
    expect(
        output.regions,
        contains('bool<span class="region informative-region" data-offset="4" '
            'data-line="1"> </span> a = true &amp;&amp; false;'));
  }

  Future<void> test_regionsContainsEscapedHtml_betweenRegions() async {
    await buildInfoForSingleTestFile('List<String> a = null;',
        migratedContent: 'List<String >? a = null;');
    var output = renderUnits()[0];
    var regions = _stripDataAttributes(output.regions);
    expect(
        regions,
        contains(
            'List&lt;String<span class="region informative-region"> </span>&gt;'
            '<span class="region added-region">?</span> a = null;'));
  }

  Future<void> test_regionsContainsEscapedHtml_region() async {
    await buildInfoForSingleTestFile('f(List<String> a) => a.join(",");',
        migratedContent: 'f(List<String >  a) => a.join(",");');
    var output = renderUnits()[0];
    var regions = _stripDataAttributes(output.regions);
    expect(
        regions,
        contains(
            'List&lt;String<span class="region informative-region"> </span>'
            '&gt;<span class="region informative-region"> </span>'));
  }

  UnitInfo unit(String path, String content, {List<RegionInfo> regions}) {
    return UnitInfo(convertPath(path))
      ..content = content
      ..regions.addAll(regions);
  }

  /// Strip out data attributes which are not being tested here.
  String _stripDataAttributes(String html) =>
      html.replaceAll(RegExp(' data-[^=]+="[^"]+"'), '');
}
