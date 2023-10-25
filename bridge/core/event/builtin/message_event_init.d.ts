import { EventInit } from "../event_init";

// @ts-ignore
@Dictionary()
export interface MessageEventInit extends EventInit {
  data?: any;
  origin?: string;
  lastEventId?: string;
  source?: string;
  // TODO: add ports property.
}
