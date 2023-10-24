/*
* Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/

declare const __mercury_invoke_module__: (module: string, method: string, params?: any | null, fn?: (err: Error, data: any) => any) => any;
export const mercuryInvokeModule = __mercury_invoke_module__;

declare const __mercury_add_module_listener__: (moduleName: string, fn: (event: Event, extra: any) => any) => void;
export const addMercuryModuleListener = __mercury_add_module_listener__;

declare const __mercury_clear_module_listener__: () => void;
export const clearMercuryModuleListener = __mercury_clear_module_listener__;

declare const __mercury_remove_module_listener__: (name: string) => void;
export const removeMercuryModuleListener = __mercury_remove_module_listener__;

declare const __mercury_location_reload__: () => void;
export const mercuryLocationReload = __mercury_location_reload__;

declare const __mercury_print__: (log: string, level?: string) => void;
export const mercuryPrint = __mercury_print__;

declare const __mercury_is_proxy__: (obj: any) => boolean;

export const mercuryIsProxy = __mercury_is_proxy__;
