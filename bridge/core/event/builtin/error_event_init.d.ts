import { EventInit } from "../event_init";

// @ts-ignore
@Dictionary()
export interface ErrorEventInit extends EventInit {
  message?: string;
  filename?: string;
  lineno: int64;
  colno: int64;
  error: any;
}
