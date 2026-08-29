process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const candidates = [
  "postgresql://postgres.bmtadgpkckkgcmvnqobg:IQoobengaluru2908@aws-0-ap-south-1.pooler.supabase.com:5432/postgres",
  "postgresql://postgres.bmtadgpkckkgcmvnqobg:IQoobengaluru2908@aws-0-ap-south-1.pooler.supabase.com:6543/postgres",
  "postgresql://postgres.bmtadgpkckkgcmvnqobg:IQoobengaluru2908@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres",
  "postgresql://postgres.bmtadgpkckkgcmvnqobg:IQoobengaluru2908@aws-0-us-east-1.pooler.supabase.com:5432/postgres",
];

async function tryConnect(connectionString) {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000
  });

  try {
    await client.connect();
    console.log(`Connected successfully using: ${connectionString.split('@')[1]}`);
    return client;
  } catch (err) {
    console.log(`Failed to connect with ${connectionString.split('@')[1]}: ${err.message}`);
    await client.end().catch(() => {});
    return null;
  }
}

async function run() {
  let connectedClient = null;

  for (const cs of candidates) {
    connectedClient = await tryConnect(cs);
    if (connectedClient) {
      break;
    }
  }

  if (!connectedClient) {
    console.error("Could not connect to any candidate endpoint.");
    process.exit(1);
  }

  console.log("Applying RLS and Schema SQL fixes directly to Supabase DB...");

  const migrationFile = path.resolve(__dirname, '../supabase/migrations/20260829000001_fix_family_rls_and_rpc.sql');
  const sql = fs.readFileSync(migrationFile, 'utf8');

  try {
    await connectedClient.query(sql);
    console.log("Successfully executed 20260829000001_fix_family_rls_and_rpc.sql!");

    // Comprehensive fix for all RLS policies
    const additionalPolicies = `
      -- 1. Helper Functions
      CREATE OR REPLACE FUNCTION public.is_family_admin(f_id UUID)
      RETURNS BOOLEAN AS $$
      BEGIN
          RETURN EXISTS (
              SELECT 1 FROM public.families
              WHERE id = f_id AND admin_user_id = auth.uid()
          ) OR EXISTS (
              SELECT 1 FROM public.family_members
              WHERE family_id = f_id AND user_id = auth.uid() AND role = 'ADMIN'
          );
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;

      CREATE OR REPLACE FUNCTION public.is_family_member(f_id UUID)
      RETURNS BOOLEAN AS $$
      BEGIN
          RETURN EXISTS (
              SELECT 1 FROM public.families
              WHERE id = f_id AND admin_user_id = auth.uid()
          ) OR EXISTS (
              SELECT 1 FROM public.family_members
              WHERE family_id = f_id AND user_id = auth.uid()
          );
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;

      -- 2. Families RLS
      DROP POLICY IF EXISTS "Family members can view their family" ON public.families;
      DROP POLICY IF EXISTS "Family members and admin can view their family" ON public.families;
      DROP POLICY IF EXISTS "Parents can create a family" ON public.families;
      DROP POLICY IF EXISTS "Admins can update their family" ON public.families;

      CREATE POLICY "Family members and admin can view their family"
          ON public.families FOR SELECT
          USING (admin_user_id = auth.uid() OR public.is_family_member(id));

      CREATE POLICY "Parents can create a family"
          ON public.families FOR INSERT
          WITH CHECK (admin_user_id = auth.uid());

      CREATE POLICY "Admins can update their family"
          ON public.families FOR UPDATE
          USING (admin_user_id = auth.uid() OR public.is_family_admin(id));

      -- 3. Family Members RLS (Allow self & admin for SELECT, INSERT, UPDATE)
      DROP POLICY IF EXISTS "Family members can view members of the same family" ON public.family_members;
      CREATE POLICY "Family members can view members of the same family"
          ON public.family_members FOR SELECT
          USING (user_id = auth.uid() OR public.is_family_member(family_id));

      DROP POLICY IF EXISTS "Family admin can insert family members" ON public.family_members;
      CREATE POLICY "Family admin can insert family members"
          ON public.family_members FOR INSERT
          WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

      DROP POLICY IF EXISTS "Family admin and self can update family members" ON public.family_members;
      CREATE POLICY "Family admin and self can update family members"
          ON public.family_members FOR UPDATE
          USING (user_id = auth.uid() OR public.is_family_admin(family_id));

      DROP POLICY IF EXISTS "Family admin can delete family members" ON public.family_members;
      CREATE POLICY "Family admin can delete family members"
          ON public.family_members FOR DELETE
          USING (public.is_family_admin(family_id));

      -- 4. Privacy Settings RLS
      DROP POLICY IF EXISTS "Users can manage own privacy settings" ON public.privacy_settings;
      DROP POLICY IF EXISTS "Family members can view privacy settings" ON public.privacy_settings;

      CREATE POLICY "Family members can view privacy settings"
          ON public.privacy_settings FOR SELECT
          USING (user_id = auth.uid() OR public.is_family_member(family_id));

      CREATE POLICY "Users can manage own privacy settings"
          ON public.privacy_settings FOR ALL
          USING (user_id = auth.uid() OR public.is_family_admin(family_id))
          WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

      -- 5. Notification Preferences RLS
      DROP POLICY IF EXISTS "Users can manage own notification preferences" ON public.notification_preferences;

      CREATE POLICY "Users can manage own notification preferences"
          ON public.notification_preferences FOR ALL
          USING (user_id = auth.uid())
          WITH CHECK (user_id = auth.uid());

      -- 6. Child Profiles RLS
      DROP POLICY IF EXISTS "Child can view own profile" ON public.child_profiles;
      DROP POLICY IF EXISTS "Parent can view child profiles in their family" ON public.child_profiles;
      DROP POLICY IF EXISTS "Parent can create child profile in their family" ON public.child_profiles;
      DROP POLICY IF EXISTS "Parent can update child profile in their family" ON public.child_profiles;

      CREATE POLICY "Child and Parent can view child profiles"
          ON public.child_profiles FOR SELECT
          USING (user_id = auth.uid() OR public.is_family_admin(family_id));

      CREATE POLICY "Parent and child can create child profile"
          ON public.child_profiles FOR INSERT
          WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

      CREATE POLICY "Parent can update child profile in their family"
          ON public.child_profiles FOR UPDATE
          USING (public.is_family_admin(family_id));

      -- Reload PostgREST Cache
      NOTIFY pgrst, 'reload schema';
      NOTIFY pgrst, 'reload config';
    `;
    await connectedClient.query(additionalPolicies);
    console.log("ALL RLS POLICIES APPLIED & POSTGREST CACHE RELOADED SUCCESSFULLY!");

  } catch (e) {
    console.error("Error executing migration query:", e);
  } finally {
    await connectedClient.end();
  }
}

run();
