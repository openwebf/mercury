import {ErrorEventInit} from "./error_event_init";
import {Event} from "../event";

interface ErrorEvent extends Event {
  readonly message: string;
  readonly filename: string;
  readonly lineno: number;
  readonly colno: number;
  readonly error: any;
  [key: string]: any;
  new(eventType: string, init?: ErrorEventInit) : ErrorEvent;
}
