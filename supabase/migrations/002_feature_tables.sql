-- Supabase Migration: Phase 2+ Feature Tables
-- fitness + finance + travel + food + privacy-first RLS

-- ============================================
-- Helper functions
-- ============================================

CREATE OR REPLACE FUNCTION is_squad_member(p_squad_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM squad_members
    WHERE squad_id = p_squad_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_squad_captain(p_squad_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM squad_members
    WHERE squad_id = p_squad_id AND user_id = auth.uid() AND role = 'captain'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================
-- Fitness
-- ============================================

CREATE TABLE workout_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  plan_type TEXT NOT NULL CHECK (
    plan_type IN ('muscle_gain', 'fat_loss', 'body_shaping', 'custom')
  ),
  description TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE workout_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "workout_plans_select" ON workout_plans
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "workout_plans_insert" ON workout_plans
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND created_by = auth.uid());

CREATE POLICY "workout_plans_update" ON workout_plans
  FOR UPDATE USING (is_squad_captain(squad_id) OR created_by = auth.uid());

CREATE POLICY "workout_plans_delete" ON workout_plans
  FOR DELETE USING (is_squad_captain(squad_id) OR created_by = auth.uid());

CREATE TABLE daily_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  task_type TEXT NOT NULL CHECK (
    task_type IN ('stretch', 'cardio', 'night_run', 'home_training', 'custom')
  ),
  target_value NUMERIC,
  target_unit TEXT,
  recurring_days INT[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,6,7],
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE daily_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_tasks_select" ON daily_tasks
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "daily_tasks_insert" ON daily_tasks
  FOR INSERT WITH CHECK (is_squad_member(squad_id));

CREATE POLICY "daily_tasks_update" ON daily_tasks
  FOR UPDATE USING (is_squad_captain(squad_id) OR created_by = auth.uid());

CREATE TABLE check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES daily_tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  value NUMERIC,
  note TEXT,
  checked_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (task_id, user_id, checked_at)
);

ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "check_ins_select" ON check_ins
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "check_ins_insert" ON check_ins
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND user_id = auth.uid());

CREATE POLICY "check_ins_update" ON check_ins
  FOR UPDATE USING (user_id = auth.uid());

CREATE TABLE health_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  weight NUMERIC,
  workout_minutes INT,
  calories_burned INT,
  recorded_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, squad_id, recorded_date)
);

ALTER TABLE health_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "health_snapshots_select" ON health_snapshots
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "health_snapshots_insert" ON health_snapshots
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND user_id = auth.uid());

CREATE POLICY "health_snapshots_update" ON health_snapshots
  FOR UPDATE USING (user_id = auth.uid());

-- ============================================
-- Finance
-- ============================================

CREATE TABLE public_funds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  fund_type TEXT NOT NULL CHECK (
    fund_type IN ('travel', 'dining', 'team_building', 'custom')
  ),
  target_amount NUMERIC NOT NULL DEFAULT 0,
  current_amount NUMERIC NOT NULL DEFAULT 0,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public_funds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_funds_select" ON public_funds
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "public_funds_insert" ON public_funds
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND created_by = auth.uid());

CREATE POLICY "public_funds_update" ON public_funds
  FOR UPDATE USING (is_squad_member(squad_id));

CREATE TABLE fund_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fund_id UUID NOT NULL REFERENCES public_funds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  amount NUMERIC NOT NULL,
  description TEXT,
  approved_by UUID REFERENCES profiles(id),
  transaction_date TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE fund_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fund_transactions_select" ON fund_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public_funds f
      WHERE f.id = fund_id AND is_squad_member(f.squad_id)
    )
  );

CREATE POLICY "fund_transactions_insert" ON fund_transactions
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public_funds f
      WHERE f.id = fund_id AND is_squad_member(f.squad_id)
    )
  );

CREATE TABLE private_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  asset_type TEXT NOT NULL CHECK (
    asset_type IN ('savings', 'stock', 'fund', 'other')
  ),
  name TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE private_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "private_assets_owner_only" ON private_assets
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TRIGGER private_assets_updated_at
  BEFORE UPDATE ON private_assets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TABLE shared_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  paid_by UUID NOT NULL REFERENCES profiles(id),
  amount NUMERIC NOT NULL,
  category TEXT NOT NULL CHECK (
    category IN ('dining', 'transport', 'entertainment', 'other')
  ),
  description TEXT,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  needs_approval BOOLEAN NOT NULL DEFAULT false,
  approved_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE shared_expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shared_expenses_select" ON shared_expenses
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "shared_expenses_insert" ON shared_expenses
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND paid_by = auth.uid());

CREATE POLICY "shared_expenses_update" ON shared_expenses
  FOR UPDATE USING (is_squad_member(squad_id));

CREATE TABLE watchlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  name TEXT NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('stock', 'fund')),
  added_by UUID NOT NULL REFERENCES profiles(id),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (squad_id, symbol)
);

ALTER TABLE watchlist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "watchlist_items_select" ON watchlist_items
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "watchlist_items_insert" ON watchlist_items
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND added_by = auth.uid());

-- ============================================
-- Travel
-- ============================================

CREATE TABLE travel_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  destination TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  budget NUMERIC NOT NULL DEFAULT 0,
  linked_fund_id UUID REFERENCES public_funds(id),
  notes TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE travel_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "travel_plans_select" ON travel_plans
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "travel_plans_insert" ON travel_plans
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND created_by = auth.uid());

CREATE POLICY "travel_plans_update" ON travel_plans
  FOR UPDATE USING (is_squad_member(squad_id));

-- ============================================
-- Food
-- ============================================

CREATE TABLE food_spots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  average_cost NUMERIC NOT NULL DEFAULT 0,
  calories_estimate INT NOT NULL DEFAULT 0,
  address TEXT,
  note TEXT,
  added_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE food_spots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "food_spots_select" ON food_spots
  FOR SELECT USING (is_squad_member(squad_id));

CREATE POLICY "food_spots_insert" ON food_spots
  FOR INSERT WITH CHECK (is_squad_member(squad_id) AND added_by = auth.uid());

CREATE TABLE food_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_spot_id UUID NOT NULL REFERENCES food_spots(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  vote INT NOT NULL CHECK (vote BETWEEN -1 AND 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (food_spot_id, user_id)
);

ALTER TABLE food_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "food_votes_select" ON food_votes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM food_spots fs
      WHERE fs.id = food_spot_id AND is_squad_member(fs.squad_id)
    )
  );

CREATE POLICY "food_votes_upsert_own" ON food_votes
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM food_spots fs
      WHERE fs.id = food_spot_id AND is_squad_member(fs.squad_id)
    )
  );

