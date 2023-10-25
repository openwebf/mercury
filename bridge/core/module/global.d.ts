import {EventTarget} from "../event/event_target";
import {GlobalEventHandlers} from "./global_event_handlers";

interface Global extends EventTarget, GlobalEventHandlers {
  // base64 utility methods
  btoa(string: string): string;
  atob(string: string): string;

  postMessage(message: any, targetOrigin: string): void;
  postMessage(message: any): void;

  readonly global: Global;
  readonly parent: Global;
  readonly self: Global;

  new(): void;
}
