-- ==============================================================================
-- SehatPass Migration: Profile & Clinic Images Storage Schema (Phase 3)
-- ==============================================================================
-- 1. Ensure avatar_url column on public.profiles
-- 2. Ensure photo_url column on public.doctor_profiles
-- 3. Ensure logo_url column on public.clinics
-- 4. Create dedicated `profile-images` storage bucket
-- 5. Storage RLS policies:
--    - Scoped strictly to auth.uid() for INSERT, UPDATE, and DELETE
--    - Authenticated SELECT policy for viewing avatars and clinic logos
--    - Zero access to medical reports or sensitive medical data
-- ==============================================================================

-- 1. Database Columns
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

ALTER TABLE public.doctor_profiles
ADD COLUMN IF NOT EXISTS photo_url TEXT;

ALTER TABLE public.clinics
ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- 2. Create profile-images Storage Bucket if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-images',
    'profile-images',
    false,
    5242880, -- 5 MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- 3. Storage RLS Policies for `profile-images`

-- A. SELECT Policy: Authenticated users can view avatars and clinic logos
DROP POLICY IF EXISTS "Authenticated users can view profile images" ON storage.objects;
CREATE POLICY "Authenticated users can view profile images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'profile-images'
);

-- B. INSERT Policy: Users can only upload to their own user-scoped directory
DROP POLICY IF EXISTS "Users can upload their own profile images" ON storage.objects;
CREATE POLICY "Users can upload their own profile images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- C. UPDATE Policy: Users can only update their own profile images
DROP POLICY IF EXISTS "Users can update their own profile images" ON storage.objects;
CREATE POLICY "Users can update their own profile images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'profile-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'profile-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- D. DELETE Policy: Users can only delete their own profile images
DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;
CREATE POLICY "Users can delete their own profile images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'profile-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
