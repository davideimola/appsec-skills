import { type Ctx, Forbidden, requireAdmin } from "./projects-service.js";

/**
 * Archives projects in bulk, behind the admin guard.
 *
 * The rule: an admin may archive only projects their own organization owns,
 * as the directory says. A caller with no organization, or one unknown or
 * foreign project in the list, refuses the whole request: a bulk write is
 * never applied to the allowed part only.
 */
export const archiveProjects = requireAdmin(async (ctx: Ctx, projectIds: string[]) => {
  const orgId = ctx.caller?.orgId ?? "";
  if (orgId === "") {
    throw new Forbidden("no organization");
  }
  for (const id of projectIds) {
    if ((await ctx.directory.projectOrg(id)) !== orgId) {
      throw new Forbidden(`project ${id} is not in ${orgId}`);
    }
  }
  await ctx.store.archive(projectIds);
});
