-- ==============================================================================
-- SehatPass Migration: Profiles RLS & Identity Relationship Access (Phase 5A.4)
-- ==============================================================================
-- 1. Enforce Row Level Security (RLS) on public.profiles
-- 2. Define strict, decoupled SELECT policies:
--    - Users can view their own profile (id = auth.uid())
--    - Authenticated users can view published doctor profiles (doctor_profiles.is_published = true)
--    - Authenticated doctors can view profiles of assigned patients with active appointments
--      (appointments.status IN ('pending', 'confirmed', 'completed') AND appointments.doctor_id = auth.uid())
--    - Authenticated patients can view profiles of doctors with whom they have active appointments
--      (appointments.status IN ('pending', 'confirmed', 'completed') AND appointments.patient_id = auth.uid())
-- 3. Zero leakage across unassigned doctors or unassigned patients
-- 4. Minimum least-privilege grants to authenticated role
-- ==============================================================================

-- 1. Ensure RLS is enabled on public.profiles
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Policy: Users can view their own profile
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- 3. Policy: Authenticated users can view published doctor profiles (Find a Doctor discovery)
DROP POLICY IF EXISTS "Authenticated users can view published doctor profiles" ON public.profiles;
CREATE POLICY "Authenticated users can view published doctor profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = profiles.id
          AND dp.is_published = true
    )
);

-- 4. Policy: Doctors can view profiles of assigned patients with active appointments
DROP POLICY IF EXISTS "Doctors can view profiles of assigned patients" ON public.profiles;
CREATE POLICY "Doctors can view profiles of assigned patients"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.patient_id = profiles.id
          AND a.doctor_id = auth.uid()
          AND a.status IN ('pending', 'confirmed', 'completed')
    )
);

-- 5. Policy: Patients can view profiles of their appointment doctors
DROP POLICY IF EXISTS "Patients can view profiles of their appointment doctors" ON public.profiles;
CREATE POLICY "Patients can view profiles of their appointment doctors"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.doctor_id = profiles.id
          AND a.patient_id = auth.uid()
          AND a.status IN ('pending', 'confirmed', 'completed')
    )
);

-- 6. Explicit privilege grants
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;
