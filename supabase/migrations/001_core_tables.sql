-- Supabase Migration: Phase 1 - Core Tables
-- profiles + squads + squad_members + RLS

-- ============================================
-- 1. Profiles 表
-- ============================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL,
  avatar_url TEXT,
  phone TEXT UNIQUE,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 用户可以读取任何 profile（成员之间需要看到彼此信息）
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (true);

-- 用户只能修改自己的 profile
CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE USING (id = auth.uid());

-- 用户创建自己的 profile
CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (id = auth.uid());

-- ============================================
-- 2. Squads 表
-- ============================================
CREATE TABLE squads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  invite_code TEXT UNIQUE NOT NULL,
  max_members INT NOT NULL DEFAULT 9 CHECK (max_members BETWEEN 2 AND 9),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE squads ENABLE ROW LEVEL SECURITY;

-- 小队成员可以查看小队信息
CREATE POLICY "squads_select" ON squads
  FOR SELECT USING (
    id IN (SELECT squad_id FROM squad_members WHERE user_id = auth.uid())
  );

-- 任何已认证用户可以创建小队
CREATE POLICY "squads_insert" ON squads
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 只有队长可以更新小队信息
CREATE POLICY "squads_update" ON squads
  FOR UPDATE USING (
    id IN (
      SELECT squad_id FROM squad_members
      WHERE user_id = auth.uid() AND role = 'captain'
    )
  );

-- 只有队长可以删除小队
CREATE POLICY "squads_delete" ON squads
  FOR DELETE USING (
    id IN (
      SELECT squad_id FROM squad_members
      WHERE user_id = auth.uid() AND role = 'captain'
    )
  );

-- ============================================
-- 3. Squad Members 表
-- ============================================
CREATE TABLE squad_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('captain', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (squad_id, user_id)
);

ALTER TABLE squad_members ENABLE ROW LEVEL SECURITY;

-- 小队成员可以查看同小队的成员列表
CREATE POLICY "squad_members_select" ON squad_members
  FOR SELECT USING (
    squad_id IN (SELECT squad_id FROM squad_members WHERE user_id = auth.uid())
  );

-- 任何已认证用户可以加入小队（通过邀请码，人数校验在应用层）
CREATE POLICY "squad_members_insert" ON squad_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- 队长可以更新成员角色
CREATE POLICY "squad_members_update" ON squad_members
  FOR UPDATE USING (
    squad_id IN (
      SELECT squad_id FROM squad_members
      WHERE user_id = auth.uid() AND role = 'captain'
    )
  );

-- 队长可以移除成员，成员可以退出
CREATE POLICY "squad_members_delete" ON squad_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR squad_id IN (
      SELECT squad_id FROM squad_members
      WHERE user_id = auth.uid() AND role = 'captain'
    )
  );

-- ============================================
-- 4. 辅助函数
-- ============================================

-- 生成 6 位邀请码
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
DECLARE
  code TEXT;
  exists_count INT;
BEGIN
  LOOP
    code := upper(substr(md5(random()::text), 1, 6));
    SELECT COUNT(*) INTO exists_count FROM squads WHERE invite_code = code;
    EXIT WHEN exists_count = 0;
  END LOOP;
  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- 获取小队当前成员数
CREATE OR REPLACE FUNCTION get_squad_member_count(p_squad_id UUID)
RETURNS INT AS $$
  SELECT COUNT(*)::INT FROM squad_members WHERE squad_id = p_squad_id;
$$ LANGUAGE sql STABLE;

-- 自动更新 updated_at 触发器
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER squads_updated_at
  BEFORE UPDATE ON squads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
