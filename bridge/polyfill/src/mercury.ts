/*
* Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/

import { addMercuryModuleListener, mercuryInvokeModule, clearMercuryModuleListener, removeMercuryModuleListener } from './bridge';
import { methodChannel, triggerMethodCallHandler } from './method-channel';

addMercuryModuleListener('MethodChannel', (event, data) => triggerMethodCallHandler(data[0], data[1]));

class MercuryDispatcher extends EventTarget {
  constructor() {
    super();
  }

  dispatch(eventName: string, ...data: any[]) {
    /* @ts-ignore */
    return this.dispatchToDart(eventName, data);
  }
}

export const mercury = {
  methodChannel,
  invokeModule: mercuryInvokeModule,
  addMercuryModuleListener: addMercuryModuleListener,
  clearMercuryModuleListener: clearMercuryModuleListener,
  removeMercuryModuleListener: removeMercuryModuleListener,
  dispatcher: new MercuryDispatcher()
};
