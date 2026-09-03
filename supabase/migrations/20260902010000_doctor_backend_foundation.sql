-- ==============================================================================
-- SehatPass Migration: Doctor Backend Foundation, Grants & Strict RLS Policies
-- ==============================================================================
-- 1. Grant least-privilege authenticated permissions for Doctor-managed tables:
--    - profiles (SELECT, UPDATE)
--    - doctor_profiles (SELECT, INSERT, UPDATE)
--    - clinics (SELECT, INSERT, UPDATE, DELETE)
--    - clinic_services (SELECT, INSERT, UPDATE, DELETE)
--    - doctor_availability (SELECT, INSERT, UPDATE, DELETE)
-- 2. Enforce strict ownership boundaries via Row Level Security (RLS):
--    - All mutations strictly checked against auth.uid()
--    - clinic_services verified against owned clinics
--    - doctor_availability verified against owned clinics
-- 3. Profile immutability trigger preventing client mutation of 'id' and 'role'
-- ==============================================================================

-- 1. Profile Security Trigger: Prevent client modification of id and role
CREATE OR REPLACE FUNCTION public.validate_profile_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Allow service_role to bypass trigger checks
    IF current_user = 'service_role' OR auth.uid() IS NULL THEN
        NEW.updated_at := now();
        RETURN NEW;
    END IF;

    -- Prevent modifying primary key / auth id
    IF NEW.id != OLD.id THEN
        RAISE EXCEPTION 'Cannot modify profile user ID.';
    END IF;

    -- Prevent modifying user role (role transitions must be administrative)
    IF NEW.role != OLD.role THEN
        RAISE EXCEPTION 'Cannot modify user account role.';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_profile_update ON public.profiles;
CREATE TRIGGER trg_validate_profile_update
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_profile_update();

-- 2. Profiles Table RLS Policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'profiles'
          AND policyname = 'Users can update their own profile'
    ) THEN
        CREATE POLICY "Users can update their own profile"
        ON public.profiles
        FOR UPDATE
        TO authenticated
        USING (id = auth.uid())
        WITH CHECK (id = auth.uid());
    END IF;
END $$;

-- 3. Doctor Profiles RLS Policies
-- INSERT: Doctor can insert their own profile
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'doctor_profiles'
          AND policyname = 'Doctors can insert their own doctor profile'
    ) THEN
        CREATE POLICY "Doctors can insert their own doctor profile"
        ON public.doctor_profiles
        FOR INSERT
        TO authenticated
        WITH CHECK (doctor_id = auth.uid());
    END IF;
END $$;

-- UPDATE: Doctor can update their own profile
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'doctor_profiles'
          AND policyname = 'Doctors can update their own doctor profile'
    ) THEN
        CREATE POLICY "Doctors can update their own doctor profile"
        ON public.doctor_profiles
        FOR UPDATE
        TO authenticated
        USING (doctor_id = auth.uid())
        WITH CHECK (doctor_id = auth.uid());
    END IF;
END $$;

-- 4. Clinics RLS Policies
-- INSERT: Doctor can insert clinics owned by themselves
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinics'
          AND policyname = 'Doctors can insert their own clinics'
    ) THEN
        CREATE POLICY "Doctors can insert their own clinics"
        ON public.clinics
        FOR INSERT
        TO authenticated
        WITH CHECK (doctor_id = auth.uid());
    END IF;
END $$;

-- UPDATE: Doctor can update only their owned clinics
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinics'
          AND policyname = 'Doctors can update their own clinics'
    ) THEN
        CREATE POLICY "Doctors can update their own clinics"
        ON public.clinics
        FOR UPDATE
        TO authenticated
        USING (doctor_id = auth.uid())
        WITH CHECK (doctor_id = auth.uid());
    END IF;
END $$;

-- DELETE: Doctor can delete only their owned clinics
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinics'
          AND policyname = 'Doctors can delete their own clinics'
    ) THEN
        CREATE POLICY "Doctors can delete their own clinics"
        ON public.clinics
        FOR DELETE
        TO authenticated
        USING (doctor_id = auth.uid());
    END IF;
END $$;

-- 5. Clinic Services RLS Policies
-- INSERT: Doctor can insert services only for their own doctor_id AND their own clinic
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinic_services'
          AND policyname = 'Doctors can insert their own clinic services'
    ) THEN
        CREATE POLICY "Doctors can insert their own clinic services"
        ON public.clinic_services
        FOR INSERT
        TO authenticated
        WITH CHECK (
            doctor_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM public.clinics c
                WHERE c.id = clinic_services.clinic_id
                  AND c.doctor_id = auth.uid()
            )
        );
    END IF;
END $$;

-- UPDATE: Doctor can update services belonging to them and their own clinic
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinic_services'
          AND policyname = 'Doctors can update their own clinic services'
    ) THEN
        CREATE POLICY "Doctors can update their own clinic services"
        ON public.clinic_services
        FOR UPDATE
        TO authenticated
        USING (
            doctor_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM public.clinics c
                WHERE c.id = clinic_services.clinic_id
                  AND c.doctor_id = auth.uid()
            )
        )
        WITH CHECK (
            doctor_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM public.clinics c
                WHERE c.id = clinic_services.clinic_id
                  AND c.doctor_id = auth.uid()
            )
        );
    END IF;
END $$;

-- DELETE: Doctor can delete services belonging to them and their own clinic
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinic_services'
          AND policyname = 'Doctors can delete their own clinic services'
    ) THEN
        CREATE POLICY "Doctors can delete their own clinic services"
        ON public.clinic_services
        FOR DELETE
        TO authenticated
        USING (
            doctor_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM public.clinics c
                WHERE c.id = clinic_services.clinic_id
                  AND c.doctor_id = auth.uid()
            )
        );
    END IF;
END $$;

-- 6. Doctor Availability RLS Policies
-- INSERT: Doctor can insert availability for themselves and their owned clinic (if clinic_id is present)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'doctor_availability'
          AND policyname = 'Doctors can insert their own availability'
    ) THEN
        CREATE POLICY "Doctors can insert their own availability"
        ON public.doctor_availability
        FOR INSERT
        TO authenticated
        WITH CHECK (
            doctor_id = auth.uid()
            AND (
                clinic_id IS NULL
                OR EXISTS (
                    SELECT 1 FROM public.clinics c
                    WHERE c.id = doctor_availability.clinic_id
                      AND c.doctor_id = auth.uid()
                )
            )
        );
    END IF;
END $$;

-- UPDATE: Doctor can update their own availability
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'doctor_availability'
          AND policyname = 'Doctors can update their own availability'
    ) THEN
        CREATE POLICY "Doctors can update their own availability"
        ON public.doctor_availability
        FOR UPDATE
        TO authenticated
        USING (
            doctor_id = auth.uid()
        )
        WITH CHECK (
            doctor_id = auth.uid()
            AND (
                clinic_id IS NULL
                OR EXISTS (
                    SELECT 1 FROM public.clinics c
                    WHERE c.id = doctor_availability.clinic_id
                      AND c.doctor_id = auth.uid()
                )
            )
        );
    END IF;
END $$;

-- DELETE: Doctor can delete their own availability
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'doctor_availability'
          AND policyname = 'Doctors can delete their own availability'
    ) THEN
        CREATE POLICY "Doctors can delete their own availability"
        ON public.doctor_availability
        FOR DELETE
        TO authenticated
        USING (doctor_id = auth.uid());
    END IF;
END $$;

-- 7. Grant Minimum Required Privileges to Authenticated Role (No Anon Mutations)
GRANT SELECT, UPDATE ON TABLE public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.doctor_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.clinics TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.clinic_services TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.doctor_availability TO authenticated;

-- Service Role Full Grants
GRANT ALL ON TABLE public.doctor_profiles TO service_role;
GRANT ALL ON TABLE public.clinics TO service_role;
GRANT ALL ON TABLE public.clinic_services TO service_role;
GRANT ALL ON TABLE public.doctor_availability TO service_role;
