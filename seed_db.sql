-- ==========================================
-- SUPABASE DATABASE SEED SCRIPT
-- ==========================================
-- IMPORTANT: Run this entire script in your Supabase SQL Editor.
-- It will DELETE all existing books, then create:
-- 2 Sellers (Chapter One Books, The Book Nook)
-- 2 Buyers (Emily Chen, David Rodriguez)
-- 12 Real Books with authentic authors and images.
-- Password for all accounts: password123
-- ==========================================

-- 0. Clear old books (Be careful! This deletes all books in the database)
DELETE FROM public.books;

-- 1. Insert 2 Sellers and 2 Buyers into Supabase Auth
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, 
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, 
  created_at, updated_at
)
VALUES
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seller1@test.com', crypt('password123', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"role":"seller"}', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seller2@test.com', crypt('password123', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"role":"seller"}', NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'buyer1@test.com', crypt('password123', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"role":"buyer"}', NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'buyer2@test.com', crypt('password123', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"role":"buyer"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- 2. Insert into auth.identities to ensure smooth login
INSERT INTO auth.identities (
  id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
)
VALUES
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', format('{"sub":"%s","email":"%s"}', '11111111-1111-1111-1111-111111111111', 'seller1@test.com')::jsonb, 'email', NOW(), NOW(), NOW()),
  (gen_random_uuid(), '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', format('{"sub":"%s","email":"%s"}', '22222222-2222-2222-2222-222222222222', 'seller2@test.com')::jsonb, 'email', NOW(), NOW(), NOW()),
  (gen_random_uuid(), '33333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', format('{"sub":"%s","email":"%s"}', '33333333-3333-3333-3333-333333333333', 'buyer1@test.com')::jsonb, 'email', NOW(), NOW(), NOW()),
  (gen_random_uuid(), '44444444-4444-4444-4444-444444444444', '44444444-4444-4444-4444-444444444444', format('{"sub":"%s","email":"%s"}', '44444444-4444-4444-4444-444444444444', 'buyer2@test.com')::jsonb, 'email', NOW(), NOW(), NOW())
ON CONFLICT (provider_id, provider) DO NOTHING;

-- 3. Insert user profiles into the public.users table
INSERT INTO public.users (id, email, role, name, "phoneNumber", description, "profileImage")
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'seller1@test.com', 'seller', 'Chapter One Books', '1234567890', 'A great place for classic literature.', ''),
  ('22222222-2222-2222-2222-222222222222', 'seller2@test.com', 'seller', 'The Book Nook', '0987654321', 'Specializing in rare and vintage books.', ''),
  ('33333333-3333-3333-3333-333333333333', 'buyer1@test.com', 'buyer', 'Emily Chen', '1112223333', '', ''),
  ('44444444-4444-4444-4444-444444444444', 'buyer2@test.com', 'buyer', 'David Rodriguez', '4445556666', '', '')
ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name, description = EXCLUDED.description;

-- 4. Insert 12 Realistic Books into public.books (linked to the sellers)
INSERT INTO public.books (id, title, author, price, "imageUrls", description, rating, "sellerId", "storeName", quantity, genre)
VALUES 
  (gen_random_uuid(), 'The Great Gatsby', 'F. Scott Fitzgerald', 10.99, '["https://m.media-amazon.com/images/I/81QuEGw8VPL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'A striking novel of the Jazz Age.', 4.5, '11111111-1111-1111-1111-111111111111', 'Chapter One Books', 20, 'Fiction'),
  (gen_random_uuid(), 'To Kill a Mockingbird', 'Harper Lee', 12.99, '["https://m.media-amazon.com/images/I/81gepf1eMqL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'A gripping, heart-wrenching, and wholly remarkable tale of coming-of-age.', 4.8, '11111111-1111-1111-1111-111111111111', 'Chapter One Books', 15, 'Fiction'),
  (gen_random_uuid(), '1984', 'George Orwell', 9.99, '["https://m.media-amazon.com/images/I/81StSOpmkjL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'Among the seminal texts of the 20th century.', 4.6, '11111111-1111-1111-1111-111111111111', 'Chapter One Books', 30, 'Science Fiction'),
  (gen_random_uuid(), 'Pride and Prejudice', 'Jane Austen', 8.99, '["https://m.media-amazon.com/images/I/71Q1tPupKjL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'An English classic full of romance.', 4.7, '11111111-1111-1111-1111-111111111111', 'Chapter One Books', 25, 'Romance'),
  (gen_random_uuid(), 'The Catcher in the Rye', 'J.D. Salinger', 11.49, '["https://m.media-amazon.com/images/I/8125BDk3l9L._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'An initiation story of a young man passing into adulthood.', 4.3, '11111111-1111-1111-1111-111111111111', 'Chapter One Books', 10, 'Fiction'),
  (gen_random_uuid(), 'Harry Potter and the Sorcerer''s Stone', 'J.K. Rowling', 22.99, '["https://m.media-amazon.com/images/I/81iqZ2HHD-L._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'A phenomenal magical journey begins here.', 4.9, '11111111-1111-1111-1111-111111111111', 'Chapter One Books', 50, 'Fantasy'),
  
  (gen_random_uuid(), 'The Hobbit', 'J.R.R. Tolkien', 14.99, '["https://m.media-amazon.com/images/I/712cDO7d73L._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'Prelude to The Lord of the Rings.', 4.9, '22222222-2222-2222-2222-222222222222', 'The Book Nook', 40, 'Fantasy'),
  (gen_random_uuid(), 'Fahrenheit 451', 'Ray Bradbury', 10.50, '["https://m.media-amazon.com/images/I/71OFqSRI82L._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'A masterpiece of twentieth-century literature.', 4.4, '22222222-2222-2222-2222-222222222222', 'The Book Nook', 18, 'Science Fiction'),
  (gen_random_uuid(), 'Moby-Dick', 'Herman Melville', 13.99, '["https://m.media-amazon.com/images/I/610qaD5PskL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'The epic sea story of Captain Ahab.', 4.2, '22222222-2222-2222-2222-222222222222', 'The Book Nook', 5, 'Fiction'),
  (gen_random_uuid(), 'Sapiens', 'Yuval Noah Harari', 18.99, '["https://m.media-amazon.com/images/I/713jIoMO3UL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'A brief history of humankind.', 4.8, '22222222-2222-2222-2222-222222222222', 'The Book Nook', 22, 'Non-fiction'),
  (gen_random_uuid(), 'The Alchemist', 'Paulo Coelho', 15.00, '["https://m.media-amazon.com/images/I/61HAE8zahLL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'A magical story about following your dreams.', 4.7, '22222222-2222-2222-2222-222222222222', 'The Book Nook', 35, 'Fiction'),
  (gen_random_uuid(), 'Dune', 'Frank Herbert', 16.99, '["https://m.media-amazon.com/images/I/81ym3QUd3KL._AC_UF1000,1000_QL80_.jpg"]'::jsonb, 'The greatest science fiction novel of all time.', 4.9, '22222222-2222-2222-2222-222222222222', 'The Book Nook', 12, 'Science Fiction');
