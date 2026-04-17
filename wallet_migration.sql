-- ==========================================
-- WALLET SYSTEM — SUPABASE MIGRATION
-- ==========================================
-- Run this entire script in your Supabase SQL Editor.
-- ==========================================

-- 1. Wallets table (one row per user — buyer or seller)
CREATE TABLE IF NOT EXISTS public.wallets (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance    NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Wallet transactions ledger
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  -- 'topup'       — buyer added funds
  -- 'purchase'    — buyer paid for order (deducted)
  -- 'release'     — seller received funds after delivery
  -- 'refund'      — buyer refunded after cancellation/return
  amount      NUMERIC(12, 2) NOT NULL,
  description TEXT,
  order_id    TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Seed wallets for existing test users (safe to run multiple times)
INSERT INTO public.wallets (user_id, balance)
VALUES
  ('11111111-1111-1111-1111-111111111111', 0.00),
  ('22222222-2222-2222-2222-222222222222', 0.00),
  ('33333333-3333-3333-3333-333333333333', 100.00),
  ('44444444-4444-4444-4444-444444444444', 150.00)
ON CONFLICT (user_id) DO NOTHING;

-- 4. Enable Row Level Security
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- 5. Drop old policies if re-running
DROP POLICY IF EXISTS "Allow all wallet ops for testing" ON public.wallets;
DROP POLICY IF EXISTS "Allow all wallet_transactions ops for testing" ON public.wallet_transactions;

-- 6. Permissive policies for testing (tighten for production)
CREATE POLICY "Allow all wallet ops for testing"
  ON public.wallets FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow all wallet_transactions ops for testing"
  ON public.wallet_transactions FOR ALL USING (true) WITH CHECK (true);
