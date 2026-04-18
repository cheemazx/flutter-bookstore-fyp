-- ==========================================
-- FULL DATABASE SCHEMA FIX
-- ==========================================
-- Run this script in your Supabase SQL Editor to fix 
-- "Database error querying schema" and other missing table issues.
-- ==========================================

-- 1. Users Profile Table (Public)
CREATE TABLE IF NOT EXISTS public.users (
  id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email          TEXT NOT NULL,
  role           TEXT NOT NULL CHECK (role IN ('buyer', 'seller', 'admin')),
  name           TEXT DEFAULT '',
  "phoneNumber"  TEXT DEFAULT '',
  description    TEXT DEFAULT '',
  "profileImage" TEXT DEFAULT '',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Books Table
CREATE TABLE IF NOT EXISTS public.books (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  author        TEXT NOT NULL,
  price         NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  "imageUrls"   JSONB NOT NULL DEFAULT '[]'::jsonb,
  description   TEXT DEFAULT '',
  rating        NUMERIC(3, 2) DEFAULT 4.5,
  "sellerId"    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  "storeName"   TEXT DEFAULT '',
  quantity      INTEGER NOT NULL DEFAULT 1,
  genre         TEXT DEFAULT 'Fiction',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Orders Table
CREATE TABLE IF NOT EXISTS public.orders (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  items              JSONB NOT NULL DEFAULT '[]'::jsonb,
  "totalAmount"      NUMERIC(12, 2) NOT NULL,
  status             TEXT NOT NULL DEFAULT 'Processing',
  timestamp          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "sellerIds"        JSONB NOT NULL DEFAULT '[]'::jsonb,
  "cancellationReason" TEXT,
  "statusHistory"    JSONB NOT NULL DEFAULT '[]'::jsonb,
  "invoiceNumber"    TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId"   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  message    TEXT NOT NULL,
  "orderId"  UUID,
  type       TEXT NOT NULL,
  "isRead"   BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Wallets Table
CREATE TABLE IF NOT EXISTS public.wallets (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance    NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Wallet Transactions Ledger
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL, 
  amount      NUMERIC(12, 2) NOT NULL,
  description TEXT,
  order_id    TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Top-up Requests (Admin System)
CREATE TABLE IF NOT EXISTS public.topup_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount         NUMERIC(12, 2) NOT NULL,
  screenshot_url TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'pending',
  admin_note     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at    TIMESTAMPTZ
);

-- 8. Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.topup_requests ENABLE ROW LEVEL SECURITY;

-- 9. Create Permissive Policies for Testing
-- NOTE: In production, you should tighten these policies.
DO $$ 
BEGIN
    -- users
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all for testing' AND tablename = 'users') THEN
        CREATE POLICY "Allow all for testing" ON public.users FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- books
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all for testing' AND tablename = 'books') THEN
        CREATE POLICY "Allow all for testing" ON public.books FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- orders
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all for testing' AND tablename = 'orders') THEN
        CREATE POLICY "Allow all for testing" ON public.orders FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- notifications
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all for testing' AND tablename = 'notifications') THEN
        CREATE POLICY "Allow all for testing" ON public.notifications FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- wallets
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all for testing' AND tablename = 'wallets') THEN
        CREATE POLICY "Allow all for testing" ON public.wallets FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- wallet_transactions
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all for testing' AND tablename = 'wallet_transactions') THEN
        CREATE POLICY "Allow all for testing" ON public.wallet_transactions FOR ALL USING (true) WITH CHECK (true);
    END IF;
    -- topup_requests
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow all for testing' AND tablename = 'topup_requests') THEN
        CREATE POLICY "Allow all for testing" ON public.topup_requests FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 10. Seed Admin Account if missing
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

INSERT INTO public.users (id, email, role, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'admin@bookstore.com', 'admin', 'System Admin')
ON CONFLICT (id) DO UPDATE SET role = 'admin';

INSERT INTO public.wallets (user_id, balance)
VALUES ('00000000-0000-0000-0000-000000000001', 0.00)
ON CONFLICT (user_id) DO NOTHING;
