process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const { Client } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const connectionString =
  process.env.DIRECT_URL ||
  process.env.DATABASE_URL ||
  process.env.SUPABASE_DATABASE_URL;

async function fix() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
  });

  await client.connect();
  console.log('✅ Connected to Supabase PostgreSQL database');

  const sql = `
    -- 1. Ensure unique constraints
    DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_privacy_user_family' OR conname = 'uq_privacy_settings_family_user') THEN
        ALTER TABLE public.privacy_settings ADD CONSTRAINT uq_privacy_user_family UNIQUE (family_id, user_id);
      END IF;
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN null;
    END $$;

    DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_family_members' OR conname = 'uq_family_members_family_user') THEN
        ALTER TABLE public.family_members ADD CONSTRAINT uq_family_members_family_user UNIQUE (family_id, user_id);
      END IF;
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN null;
    END $$;

    -- 2. Update trigger handle_new_family to use ON CONFLICT (user_id) for notification_preferences
    CREATE OR REPLACE FUNCTION public.handle_new_family()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Add creator as ADMIN in family_members
        INSERT INTO public.family_members (family_id, user_id, role)
        VALUES (NEW.id, NEW.admin_user_id, 'ADMIN')
        ON CONFLICT (family_id, user_id) DO UPDATE SET role = 'ADMIN';

        -- Default Privacy Settings
        INSERT INTO public.privacy_settings (family_id, user_id, anonymize_data, local_processing_only, data_retention_days)
        VALUES (NEW.id, NEW.admin_user_id, true, true, 30)
        ON CONFLICT (family_id, user_id) DO UPDATE SET updated_at = NOW();

        -- Default Notification Preferences (unique on user_id)
        INSERT INTO public.notification_preferences (family_id, user_id, daily_summary, instant_alerts, quiet_hours_start, quiet_hours_end)
        VALUES (NEW.id, NEW.admin_user_id, true, true, '21:00', '07:00')
        ON CONFLICT (user_id) DO UPDATE SET family_id = EXCLUDED.family_id, updated_at = NOW();

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    DROP TRIGGER IF EXISTS on_family_created ON public.families;
    CREATE TRIGGER on_family_created
        AFTER INSERT ON public.families
        FOR EACH ROW
        EXECUTE FUNCTION public.handle_new_family();

    -- 3. Atomic RPC function for Creating a Family Hub
    CREATE OR REPLACE FUNCTION public.create_family_hub(
        p_name TEXT
    )
    RETURNS JSONB AS $$
    DECLARE
        v_user_id UUID;
        v_family RECORD;
    BEGIN
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RAISE EXCEPTION 'Authentication required';
        END IF;

        INSERT INTO public.families (name, admin_user_id)
        VALUES (p_name, v_user_id)
        RETURNING * INTO v_family;

        INSERT INTO public.family_members (family_id, user_id, role)
        VALUES (v_family.id, v_user_id, 'ADMIN')
        ON CONFLICT (family_id, user_id) DO UPDATE SET role = 'ADMIN';

        INSERT INTO public.privacy_settings (family_id, user_id, anonymize_data, local_processing_only, data_retention_days)
        VALUES (v_family.id, v_user_id, true, true, 30)
        ON CONFLICT (family_id, user_id) DO UPDATE SET updated_at = NOW();

        INSERT INTO public.notification_preferences (family_id, user_id, daily_summary, instant_alerts, quiet_hours_start, quiet_hours_end)
        VALUES (v_family.id, v_user_id, true, true, '21:00', '07:00')
        ON CONFLICT (user_id) DO UPDATE SET family_id = EXCLUDED.family_id, updated_at = NOW();

        RETURN to_jsonb(v_family);
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- Reload PostgREST Cache
    NOTIFY pgrst, 'reload schema';
    NOTIFY pgrst, 'reload config';
  `;

  await client.query(sql);
  console.log('🎉 Successfully fixed database trigger, RPC, and constraints!');
  await client.end();
}

fix().catch((e) => {
  console.error('❌ Error fixing constraints:', e);
  process.exit(1);
});
