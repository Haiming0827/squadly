-- Unified plan metadata and task checklist. Sensitive module data remains in
-- its owning feature tables and is never copied into these records.

CREATE TABLE squad_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 100),
  description TEXT,
  category TEXT NOT NULL CHECK (
    category IN ('fitness', 'finance', 'travel', 'food', 'custom')
  ),
  visibility TEXT NOT NULL DEFAULT 'squad'
    CHECK (visibility IN ('squad', 'private')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'archived')),
  start_date DATE,
  end_date DATE,
  created_by TEXT NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date),
  UNIQUE (id, squad_id)
);

ALTER TABLE squad_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "squad_plans_select" ON squad_plans
  FOR SELECT USING (
    is_squad_member(squad_id)
    AND (visibility = 'squad' OR created_by = auth.uid())
  );

CREATE POLICY "squad_plans_insert" ON squad_plans
  FOR INSERT WITH CHECK (
    is_squad_member(squad_id)
    AND created_by = auth.uid()
    AND status = 'active'
  );

CREATE POLICY "squad_plans_update" ON squad_plans
  FOR UPDATE USING (
    is_squad_member(squad_id)
    AND (visibility = 'squad' OR created_by = auth.uid())
  ) WITH CHECK (
    is_squad_member(squad_id)
    AND (visibility = 'squad' OR created_by = auth.uid())
  );

CREATE POLICY "squad_plans_delete" ON squad_plans
  FOR DELETE USING (
    is_squad_member(squad_id)
    AND (visibility = 'squad' OR created_by = auth.uid())
  );

CREATE INDEX squad_plans_squad_status_updated_idx
  ON squad_plans (squad_id, status, updated_at DESC);
CREATE INDEX squad_plans_private_owner_idx
  ON squad_plans (squad_id, created_by, updated_at DESC)
  WHERE visibility = 'private';

CREATE TABLE squad_plan_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL,
  squad_id UUID NOT NULL,
  title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 160),
  details TEXT,
  assigned_to TEXT REFERENCES profiles(id),
  due_date DATE,
  is_complete BOOLEAN NOT NULL DEFAULT false,
  completed_by TEXT REFERENCES profiles(id),
  completed_at TIMESTAMPTZ,
  position INT NOT NULL DEFAULT 0,
  created_by TEXT NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (plan_id, squad_id)
    REFERENCES squad_plans(id, squad_id) ON DELETE CASCADE,
  CHECK (
    (is_complete = false AND completed_by IS NULL AND completed_at IS NULL)
    OR (is_complete = true AND completed_by IS NOT NULL AND completed_at IS NOT NULL)
  )
);

ALTER TABLE squad_plan_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "squad_plan_tasks_select" ON squad_plan_tasks
  FOR SELECT USING (
    is_squad_member(squad_id)
    AND EXISTS (
      SELECT 1 FROM squad_plans plan
      WHERE plan.id = squad_plan_tasks.plan_id
        AND plan.squad_id = squad_plan_tasks.squad_id
    )
  );

CREATE POLICY "squad_plan_tasks_insert" ON squad_plan_tasks
  FOR INSERT WITH CHECK (
    is_squad_member(squad_id)
    AND created_by = auth.uid()
    AND NOT is_complete
    AND completed_by IS NULL
    AND completed_at IS NULL
    AND (assigned_to IS NULL OR EXISTS (
      SELECT 1 FROM squad_members member
      WHERE member.squad_id = squad_plan_tasks.squad_id
        AND member.user_id = squad_plan_tasks.assigned_to
    ))
    AND EXISTS (
      SELECT 1 FROM squad_plans plan
      WHERE plan.id = squad_plan_tasks.plan_id
        AND plan.squad_id = squad_plan_tasks.squad_id
    )
  );

CREATE POLICY "squad_plan_tasks_update" ON squad_plan_tasks
  FOR UPDATE USING (
    is_squad_member(squad_id)
    AND EXISTS (
      SELECT 1 FROM squad_plans plan
      WHERE plan.id = plan_id AND plan.squad_id = squad_id
    )
  ) WITH CHECK (
    is_squad_member(squad_id)
    AND (completed_by IS NULL OR completed_by = auth.uid())
    AND (assigned_to IS NULL OR EXISTS (
      SELECT 1 FROM squad_members member
      WHERE member.squad_id = squad_plan_tasks.squad_id
        AND member.user_id = squad_plan_tasks.assigned_to
    ))
    AND EXISTS (
      SELECT 1 FROM squad_plans plan
      WHERE plan.id = squad_plan_tasks.plan_id
        AND plan.squad_id = squad_plan_tasks.squad_id
    )
  );

CREATE POLICY "squad_plan_tasks_delete" ON squad_plan_tasks
  FOR DELETE USING (
    is_squad_member(squad_id)
    AND EXISTS (
      SELECT 1 FROM squad_plans plan
      WHERE plan.id = squad_plan_tasks.plan_id
        AND plan.squad_id = squad_plan_tasks.squad_id
    )
  );

CREATE INDEX squad_plan_tasks_plan_position_idx
  ON squad_plan_tasks (plan_id, position, created_at);
CREATE INDEX squad_plan_tasks_squad_due_idx
  ON squad_plan_tasks (squad_id, due_date)
  WHERE is_complete = false;

CREATE FUNCTION public.touch_squad_plan_updated_at_from_task()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.squad_plans SET updated_at = now() WHERE id = OLD.plan_id;
    RETURN OLD;
  END IF;
  UPDATE public.squad_plans SET updated_at = now() WHERE id = NEW.plan_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER squad_plan_task_updates_plan_timestamp
  AFTER INSERT OR UPDATE OR DELETE ON public.squad_plan_tasks
  FOR EACH ROW EXECUTE FUNCTION public.touch_squad_plan_updated_at_from_task();

REVOKE ALL ON TABLE public.squad_plans, public.squad_plan_tasks
  FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.squad_plans, public.squad_plan_tasks TO authenticated;
REVOKE UPDATE ON TABLE public.squad_plans, public.squad_plan_tasks
  FROM authenticated;
GRANT UPDATE (
  title, description, category, visibility, status,
  start_date, end_date, updated_at
) ON TABLE public.squad_plans TO authenticated;
GRANT UPDATE (
  title, details, assigned_to, due_date, is_complete, completed_by,
  completed_at, position, updated_at
) ON TABLE public.squad_plan_tasks TO authenticated;
GRANT ALL PRIVILEGES
  ON TABLE public.squad_plans, public.squad_plan_tasks TO service_role;
