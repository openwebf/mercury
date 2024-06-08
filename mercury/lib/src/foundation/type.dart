/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

// Cast any input type to determined type.
T castToType<T>(value) {
  assert(value is T, '$value is not or not a subtype of $T');
  return value as T;
}
