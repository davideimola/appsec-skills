import type { Ctx } from "./projects-service.js";
import { requireAdmin } from "./projects-service.js";

/**
 * The vulnerable version of the handler in archive.ts, kept so CI can prove
 * the property catches it. vitest swaps it in for archive.ts only when run
 * with VULNERABLE=1 (see vitest.config.ts); nothing imports it directly.
 *
 * It asks the directory who owns each project and then discards the answer,
 * so an admin archives any organization's projects, and a caller with no
 * organization is never refused.
 */
export const archiveProjects = requireAdmin(async (ctx: Ctx, projectIds: string[]) => {
  await Promise.all(projectIds.map((id) => ctx.directory.projectOrg(id)));
  await ctx.store.archive(projectIds);
});
