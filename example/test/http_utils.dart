// Copyright 2020-present the Saltech Systems authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// A dummy URL for constructing requests that won't be sent.
Uri get dummyUrl => Uri.parse('http://dartlang.org/');

/// Removes eight spaces of leading indentation from a multiline string.
///
/// Note that this is very sensitive to how the literals are styled. They should
/// be:
///     '''
///     Text starts on own line. Lines up with subsequent lines.
///     Lines are indented exactly 8 characters from the left margin.
///     Close is on the same line.'''
///
/// This does nothing if text is only a single line.
// TODO(nweiz): Make this auto-detect the indentation level from the first
// non-whitespace line.
String cleanUpLiteral(String text) {
  var lines = text.split('\n');
  if (lines.length <= 1) return text;

  for (var j = 0; j < lines.length; j++) {
    if (lines[j].length > 8) {
      lines[j] = lines[j].substring(8, lines[j].length);
    } else {
      lines[j] = '';
    }
  }

  return lines.join('\n');
}

/// A matcher that matches JSON that parses to a value that matches the inner
/// matcher.
Matcher parse(matcher) => _Parse(matcher);

class _Parse extends Matcher {
  _Parse(this._matcher);

  final Matcher _matcher;

  @override
  bool matches(item, Map matchState) {
    if (item is! String) return false;

    dynamic parsed;
    try {
      parsed = json.decode(item);
    } catch (e) {
      return false;
    }

    return _matcher.matches(parsed, matchState);
  }

  @override
  Description describe(Description description) {
    return description
        .add('parses to a value that ')
        .addDescriptionOf(_matcher);
  }
}

/// A matcher that validates the body of a multipart request after finalization.
///
/// The string "{{boundary}}" in [pattern] will be replaced by the boundary
/// string for the request, and LF newlines will be replaced with CRLF.
/// Indentation will be normalized.
Matcher bodyMatches(String pattern) => _BodyMatches(pattern);

class _BodyMatches extends Matcher {
  _BodyMatches(this._pattern);

  final String _pattern;

  @override
  bool matches(item, Map matchState) {
    if (item is! http.MultipartRequest) return false;

    return completes.matches(_checks(item), matchState);
  }

  Future<void> _checks(http.MultipartRequest item) async {
    var bodyBytes = await item.finalize().toBytes();
    var body = utf8.decode(bodyBytes);
    var contentType = MediaType.parse(item.headers['content-type']!);
    var boundary = contentType.parameters['boundary']!;
    var expected = cleanUpLiteral(_pattern)
        .replaceAll('\n', '\r\n')
        .replaceAll('{{boundary}}', boundary);

    expect(body, equals(expected));
    expect(item.contentLength, equals(bodyBytes.length));
  }

  @override
  Description describe(Description description) {
    return description.add('has a body that matches "$_pattern"');
  }
}

/// A matcher that matches function or future that throws a
/// [http.ClientException] with the given [message].
///
/// [message] can be a String or a [Matcher].
Matcher throwsClientException(message) => throwsA(
    isA<http.ClientException>().having((e) => e.message, 'message', message));
