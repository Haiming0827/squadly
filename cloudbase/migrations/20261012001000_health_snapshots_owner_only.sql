-- Health snapshots contain personal weight data. Restore the feature path with
-- owner-only policies instead of exposing measurements to the whole squad.
DROP POLICY IF EXISTS health_snapshots_owner_select ON public.health_snapshots;
DROP POLICY IF EXISTS health_snapshots_owner_insert ON public.health_snapshots;
DROP POLICY IF EXISTS health_snapshots_owner_update ON public.health_snapshots;

CREATE POLICY health_snapshots_owner_select ON public.health_snapshots
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY health_snapshots_owner_insert ON public.health_snapshots
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid() AND public.is_squad_member(squad_id)
  );
CREATE POLICY health_snapshots_owner_update ON public.health_snapshots
  FOR UPDATE TO authenticated USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON public.health_snapshots TO authenticated;
