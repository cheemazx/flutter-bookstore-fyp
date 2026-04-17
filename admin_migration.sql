-- ==========================================
-- ADMIN SYSTEM MIGRATION
-- ==========================================
-- Run this in your Supabase SQL Editor AFTER wallet_migration.sql
-- ==========================================

-- 1. Top-up requests table
CREATE TABLE IF NOT EXISTS public.topup_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount         NUMERIC(12, 2) NOT NULL,
  screenshot_url TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'pending',
  -- 'pending' | 'approved' | 'rejected'
  admin_note     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at    TIMESTAMPTZ
);

-- 2. RLS (permissive for testing)
ALTER TABLE public.topup_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all topup_requests for testing" ON public.topup_requests;
CREATE POLICY "Allow all topup_requests for testing"
  ON public.topup_requests FOR ALL USING (true) WITH CHECK (true);

-- 3. Supabase Storage bucket for payment screenshots
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-screenshots', 'payment-screenshots', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policy: allow authenticated users to upload
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
CREATE POLICY "Allow authenticated uploads"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'payment-screenshots');

DROP POLICY IF EXISTS "Allow public reads" ON storage.objects;
CREATE POLICY "Allow public reads"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'payment-screenshots');

DROP POLICY IF EXISTS "Allow authenticated deletes" ON storage.objects;
CREATE POLICY "Allow authenticated deletes"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'payment-screenshots');

-- 4. Seed admin account in auth.users
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'admin@bookstore.com',
  crypt('admin123', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"admin"}',
  NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
VALUES (
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  format('{"sub":"%s","email":"%s"}',
    '00000000-0000-0000-0000-000000000001',
    'admin@bookstore.com')::jsonb,
  'email', NOW(), NOW(), NOW()
) ON CONFLICT (provider_id, provider) DO NOTHING;

-- 5. Seed admin profile in public.users
INSERT INTO public.users (id, email, role, name, "phoneNumber", description, "profileImage")
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'admin@bookstore.com',
  'admin',
  'System Admin',
  '', '', ''
) ON CONFLICT (id) DO UPDATE SET role = 'admin', name = 'System Admin';

-- 6. Seed wallets for admin (balance stays 0 — admin doesn't shop)
INSERT INTO public.wallets (user_id, balance)
VALUES ('00000000-0000-0000-0000-000000000001', 0.00)
ON CONFLICT (user_id) DO NOTHING;
