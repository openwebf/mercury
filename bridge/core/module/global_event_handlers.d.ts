type IDLEventHandler = Function;

// @ts-ignore
@Mixin()
export interface GlobalEventHandlers {
    onmessage: IDLEventHandler | null;
    onmessageerror: IDLEventHandler | null;
    onrejectionhandled: IDLEventHandler | null;
    onunhandledrejection: IDLEventHandler | null;
}
