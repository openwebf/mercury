/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'package:test/test.dart';
import 'package:mercury/foundation.dart';

void main() {
  group('environment', () {
    test('getMercuryTemporaryPath()', () async {
      String tempPath = await getMercuryTemporaryPath();
      expect(tempPath, './temp');
    });
  });
}
