import type { Caller } from "./project.js";

/** The service that knows which organization owns a project. */
export interface Directory {
  /** The owning organization's id, or undefined for an unknown project. */
  projectOrg(projectId: string): Promise<string | undefined>;
}

/** Where archived projects end up: the effect the check protects. */
export interface Store {
  archive(projectIds: string[]): Promise<void>;
}

/** What every handler receives. caller is undefined for an anonymous request. */
export interface Ctx {
  caller: Caller | undefined;
  directory: Directory;
  store: Store;
}

export class Forbidden extends Error {}

type Handler<A extends unknown[]> = (ctx: Ctx, ...args: A) => Promise<void>;

/** The guard in front of admin-only handlers: the role check lives here, not in the handler. */
export function requireAdmin<A extends unknown[]>(handler: Handler<A>): Handler<A> {
  return async (ctx, ...args) => {
    if (ctx.caller?.role !== "admin") {
      throw new Forbidden("admin required");
    }
    return handler(ctx, ...args);
  };
}
