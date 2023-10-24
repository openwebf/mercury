/*
* Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/

import { mercuryInvokeModule } from './bridge';

type MethodCallHandler = (args: any[]) => void;

let methodCallHandlers: {[key: string]: MethodCallHandler} = {};

// Like flutter platform channels
export const methodChannel = {
  addMethodCallHandler(method: string, handler: MethodCallHandler) {
    if (typeof handler !== 'function') {
      throw new Error('mercury.addMethodCallHandler: handler should be an function.');
    }
    methodCallHandlers[method] = handler;
  },
  removeMethodCallHandler(method: string) {
    delete methodCallHandlers[method];
  },
  clearMethodCallHandler() {
    methodCallHandlers = {};
  },
  invokeMethod(method: string, ...args: any[]): Promise<string> {
    return new Promise((resolve, reject) => {
      mercuryInvokeModule('MethodChannel', 'invokeMethod', [method, args], (e, data) => {
        if (e) return reject(e);
        resolve(data);
      });
    });
  },
};

export function triggerMethodCallHandler(method: string, args: any[]) {
  if (!methodCallHandlers.hasOwnProperty(method)) {
    return null;
  }

  return methodCallHandlers[method](args);
}
