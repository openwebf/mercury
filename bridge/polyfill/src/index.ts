/*
* Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/

import { console } from './console';
import { fetch, Request, Response, Headers } from './fetch';
import { XMLHttpRequest } from './xhr';
import { URLSearchParams } from './url-search-params';
import { URL } from './url';
import { mercury } from './mercury';
import { WebSocket } from './websocket'

defineGlobalProperty('console', console);
defineGlobalProperty('Request', Request);
defineGlobalProperty('Response', Response);
defineGlobalProperty('Headers', Headers);
defineGlobalProperty('fetch', fetch);
defineGlobalProperty('XMLHttpRequest', XMLHttpRequest);
defineGlobalProperty('URLSearchParams', URLSearchParams);
defineGlobalProperty('URL', URL);
defineGlobalProperty('mercury', mercury);
defineGlobalProperty('WebSocket', WebSocket);

function defineGlobalProperty(key: string, value: any, isEnumerable: boolean = true) {
  Object.defineProperty(globalThis, key, {
    value: value,
    enumerable: isEnumerable,
    writable: true,
    configurable: true
  });
}
