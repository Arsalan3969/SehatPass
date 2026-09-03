-- ==============================================================================
-- SehatPass Migration: Doctor Patient Access Foundation (Phase 4A)
-- ==============================================================================
-- 1. Ensure public.patient_profiles table exists with required schema
-- 2. Enforce strict, decoupled Row Level Security (RLS) policies:
--    - Patients can view and mutate ONLY their own profile (patient_id = auth.uid())
--    - Doctors can SELECT patient profiles ONLY when:
--        a. The caller is a registered doctor (doctor_profiles.doctor_id = auth.uid())
--        b. An appointment exists linking this doctor and patient with status
--           IN ('pending', 'confirmed', 'completed')
-- 3. Least-privilege grants: authenticated role granted SELECT; mutations denied to doctors
-- 4. Zero anonymous access
-- ==============================================================================

-- 1. Ensure patient_profiles table exists with proper schema
CREATE TABLE IF NOT EXISTS public.patient_profiles (
    patient_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    date_of_birth DATE NULL,
    gender TEXT NULL,
    blood_group TEXT NULL,
    allergies TEXT NOT NULL DEFAULT 'None added',
    medical_conditions TEXT NOT NULL DEFAULT 'None added',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure conditionally missing columns exist if table pre-existed
ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS blood_group TEXT;
ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS allergies TEXT DEFAULT 'None added';
ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS medical_conditions TEXT DEFAULT 'None added';
ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.patient_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Enable RLS
ALTER TABLE public.patient_profiles ENABLE ROW LEVEL SECURITY;

-- 2. RLS Policy: Patients can manage their own profile
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'patient_profiles'
          AND policyname = 'Patients can manage their own patient profile'
    ) THEN
        CREATE POLICY "Patients can manage their own patient profile"
        ON public.patient_profiles
        FOR ALL
        TO authenticated
        USING (patient_id = auth.uid())
        WITH CHECK (patient_id = auth.uid());
    END IF;
END $$;

-- 3. RLS Policy: Doctors can view profiles of assigned patients with active appointments
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'patient_profiles'
          AND policyname = 'Doctors can view profiles of assigned patients'
    ) THEN
        CREATE POLICY "Doctors can view profiles of assigned patients"
        ON public.patient_profiles
        FOR SELECT
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM public.doctor_profiles dp
                WHERE dp.doctor_id = auth.uid()
            )
            AND EXISTS (
                SELECT 1 FROM public.appointments a
                WHERE a.patient_id = patient_profiles.patient_id
                  AND a.doctor_id = auth.uid()
                  AND a.status IN ('pending', 'confirmed', 'completed')
            )
        );
    END IF;
END $$;

-- 4. Minimum required grants to authenticated role
GRANT SELECT ON TABLE public.patient_profiles TO authenticated;
GRANT ALL ON TABLE public.patient_profiles TO service_role;
