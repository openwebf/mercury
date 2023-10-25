import { EventInit } from "../event_init";

// @ts-ignore
@Dictionary()
export interface CloseEventInit extends EventInit {
    code?: int64;
    reason?: string;
    wasClean?: boolean;
}
