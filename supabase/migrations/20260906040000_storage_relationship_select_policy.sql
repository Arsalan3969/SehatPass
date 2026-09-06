-- ==============================================================================
-- SehatPass Migration: Relationship-Based Storage SELECT Policy for profile-images
-- ==============================================================================
-- 1. Keeps `profile-images` bucket strictly PRIVATE (public = false).
-- 2. Scopes SELECT access based on authorized domain relationships:
--    - Users can view their own images (self).
--    - Authenticated users can view published doctor avatars & clinic logos (booking discovery).
--    - Doctors can view patient avatars for patients who have appointments with them.
-- 3. Prohibits arbitrary cross-patient or cross-unrelated-user image access.
-- 4. Preserves isolated zero-access to medical reports storage.
-- ==============================================================================

-- Drop existing broad SELECT policy
DROP POLICY IF EXISTS "Authenticated users can view profile images" ON storage.objects;
DROP POLICY IF EXISTS "Relationship based profile images select policy" ON storage.objects;

-- Create relationship-scoped SELECT policy
CREATE POLICY "Relationship based profile images select policy"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'profile-images'
    AND (
        -- 1. Own images
        (storage.foldername(name))[1] = auth.uid()::text
        -- 2. Published doctor profiles or clinic logos (accessible for doctor discovery & booking)
        OR EXISTS (
            SELECT 1 FROM public.doctor_profiles dp
            WHERE dp.doctor_id::text = (storage.foldername(name))[1]
              AND dp.is_published = true
        )
        OR EXISTS (
            SELECT 1 FROM public.clinics c
            WHERE c.doctor_id::text = (storage.foldername(name))[1]
        )
        -- 3. Patient avatar viewed by doctor having an existing appointment
        OR EXISTS (
            SELECT 1 FROM public.appointments a
            WHERE a.patient_id::text = (storage.foldername(name))[1]
              AND a.doctor_id = auth.uid()
        )
    )
);
