-- ==============================================================================
-- SehatPass Migration: Patient App Audit Fixes, Grants & Medical Reports Hardening
-- ==============================================================================
-- 1. Add extracted_text column to public.medical_reports for Sehat AI RAG context
-- 2. Ensure doctor_profiles, clinics, clinic_services, doctor_availability, and appointments
--    tables exist with proper schemas, foreign keys, and indexes
-- 3. Enforce strict, decoupled patient & doctor access boundaries via RLS + BEFORE UPDATE trigger
-- 4. Grant authenticated role least-privilege permissions (No anon access granted)
-- ==============================================================================

-- 1. Add extracted_text to public.medical_reports
ALTER TABLE public.medical_reports
ADD COLUMN IF NOT EXISTS extracted_text TEXT NULL;

-- 2. Ensure doctor_profiles table exists and has required columns
CREATE TABLE IF NOT EXISTS public.doctor_profiles (
    doctor_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    specialization TEXT NOT NULL DEFAULT 'General Physician',
    qualifications TEXT NOT NULL DEFAULT 'MBBS',
    experience_years TEXT NOT NULL DEFAULT '1 year',
    bio TEXT NULL,
    rating NUMERIC(2,1) NOT NULL DEFAULT 5.0,
    total_reviews INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS specialization TEXT NOT NULL DEFAULT 'General Physician';
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS qualifications TEXT NOT NULL DEFAULT 'MBBS';
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS experience_years TEXT NOT NULL DEFAULT '1 year';
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS rating NUMERIC(2,1) NOT NULL DEFAULT 5.0;
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS total_reviews INT NOT NULL DEFAULT 0;
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.doctor_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Ensure clinics table exists
CREATE TABLE IF NOT EXISTS public.clinics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'Lahore',
    phone TEXT NOT NULL,
    description TEXT NULL,
    logo_url TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS doctor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Lahore';
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Ensure clinic_services table exists
CREATE TABLE IF NOT EXISTS public.clinic_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id UUID NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    fee NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.clinic_services ADD COLUMN IF NOT EXISTS clinic_id UUID REFERENCES public.clinics(id) ON DELETE CASCADE;
ALTER TABLE public.clinic_services ADD COLUMN IF NOT EXISTS doctor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.clinic_services ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.clinic_services ADD COLUMN IF NOT EXISTS fee NUMERIC(10,2) DEFAULT 0.00;
ALTER TABLE public.clinic_services ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.clinic_services ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- Ensure doctor_availability table exists
CREATE TABLE IF NOT EXISTS public.doctor_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    clinic_id UUID NULL REFERENCES public.clinics(id) ON DELETE SET NULL,
    day_of_week TEXT NOT NULL,
    start_time TIME NOT NULL DEFAULT '10:00:00',
    end_time TIME NOT NULL DEFAULT '16:00:00',
    is_available BOOLEAN NOT NULL DEFAULT true
);
ALTER TABLE public.doctor_availability ADD COLUMN IF NOT EXISTS doctor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.doctor_availability ADD COLUMN IF NOT EXISTS clinic_id UUID REFERENCES public.clinics(id) ON DELETE SET NULL;
ALTER TABLE public.doctor_availability ADD COLUMN IF NOT EXISTS day_of_week TEXT;
ALTER TABLE public.doctor_availability ADD COLUMN IF NOT EXISTS start_time TIME DEFAULT '10:00:00';
ALTER TABLE public.doctor_availability ADD COLUMN IF NOT EXISTS end_time TIME DEFAULT '16:00:00';
ALTER TABLE public.doctor_availability ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;

-- Ensure appointments table exists
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_no TEXT NOT NULL,
    patient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    clinic_id UUID NULL REFERENCES public.clinics(id) ON DELETE SET NULL,
    service_id UUID NULL REFERENCES public.clinic_services(id) ON DELETE SET NULL,
    service_name TEXT NOT NULL DEFAULT 'General Consultation',
    appointment_date DATE NOT NULL,
    appointment_time TEXT NOT NULL,
    consultation_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    platform_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    payment_status TEXT NOT NULL DEFAULT 'pending',
    payment_method TEXT NOT NULL DEFAULT 'cash',
    status TEXT NOT NULL DEFAULT 'pending',
    cancellation_reason TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure conditionally missing columns exist if table was previously created
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS reference_no TEXT;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS patient_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS doctor_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS clinic_id UUID REFERENCES public.clinics(id) ON DELETE SET NULL;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES public.clinic_services(id) ON DELETE SET NULL;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS service_name TEXT DEFAULT 'General Consultation';
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS appointment_date DATE;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS appointment_time TEXT;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS consultation_fee NUMERIC(10,2) DEFAULT 0.00;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS platform_fee NUMERIC(10,2) DEFAULT 0.00;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10,2) DEFAULT 0.00;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending';
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Indexes for performance & query optimization
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_is_published ON public.doctor_profiles (is_published);
CREATE INDEX IF NOT EXISTS idx_clinics_doctor_id ON public.clinics (doctor_id);
CREATE INDEX IF NOT EXISTS idx_clinic_services_doctor_id ON public.clinic_services (doctor_id);
CREATE INDEX IF NOT EXISTS idx_doctor_availability_doctor_id ON public.doctor_availability (doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_patient_id ON public.appointments (patient_id, appointment_date DESC);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_id ON public.appointments (doctor_id, appointment_date DESC);

-- Enable RLS on all tables
ALTER TABLE public.doctor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinic_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- 3. Row Level Security Policies for Doctor Profiles, Clinics & Availability
-- Authenticated users can view published doctor profiles or doctors viewing their own profile
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'doctor_profiles'
          AND policyname = 'Allow authenticated users to view published doctor profiles'
    ) THEN
        CREATE POLICY "Allow authenticated users to view published doctor profiles"
        ON public.doctor_profiles
        FOR SELECT
        TO authenticated
        USING (is_published = true OR doctor_id = auth.uid());
    END IF;
END $$;

-- Clinics: authenticated users can view active clinics or doctors viewing their own clinic
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinics'
          AND policyname = 'Allow authenticated users to view active clinics'
    ) THEN
        CREATE POLICY "Allow authenticated users to view active clinics"
        ON public.clinics
        FOR SELECT
        TO authenticated
        USING (is_active = true OR doctor_id = auth.uid());
    END IF;
END $$;

-- Clinic services: authenticated users can view active clinic services
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'clinic_services'
          AND policyname = 'Allow authenticated users to view active clinic services'
    ) THEN
        CREATE POLICY "Allow authenticated users to view active clinic services"
        ON public.clinic_services
        FOR SELECT
        TO authenticated
        USING (is_active = true OR doctor_id = auth.uid());
    END IF;
END $$;

-- Doctor availability: authenticated users can view doctor availability
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'doctor_availability'
          AND policyname = 'Allow authenticated users to view doctor availability'
    ) THEN
        CREATE POLICY "Allow authenticated users to view doctor availability"
        ON public.doctor_availability
        FOR SELECT
        TO authenticated
        USING (is_available = true OR doctor_id = auth.uid());
    END IF;
END $$;

-- Drop legacy / overly permissive policies on appointments if present
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'appointments'
          AND policyname = 'Patients can manage their own appointments'
    ) THEN
        DROP POLICY "Patients can manage their own appointments" ON public.appointments;
    END IF;
END $$;

-- ── SEPARATE PATIENT APPOINTMENT RLS POLICIES ─────────────────────────────

-- PATIENT SELECT: Patient can SELECT only rows where patient_id = auth.uid()
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'appointments'
          AND policyname = 'Patients can view their own appointments'
    ) THEN
        CREATE POLICY "Patients can view their own appointments"
        ON public.appointments
        FOR SELECT
        TO authenticated
        USING (patient_id = auth.uid());
    END IF;
END $$;

-- PATIENT INSERT: Patient can INSERT only their own pending cash appointment request.
-- Requires doctor_id to be a registered doctor in doctor_profiles, preventing self-booking / impersonation.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'appointments'
          AND policyname = 'Patients can insert their own appointment requests'
    ) THEN
        CREATE POLICY "Patients can insert their own appointment requests"
        ON public.appointments
        FOR INSERT
        TO authenticated
        WITH CHECK (
            patient_id = auth.uid()
            AND doctor_id != auth.uid()
            AND status = 'pending'
            AND payment_status = 'pending'
            AND payment_method = 'cash'
            AND platform_fee = 0.00
            AND EXISTS (
                SELECT 1 FROM public.doctor_profiles dp
                WHERE dp.doctor_id = appointments.doctor_id
            )
        );
    END IF;
END $$;

-- PATIENT UPDATE: Patient can initiate updates only on their own appointments.
-- Field-level immutability and status guardrails are strictly enforced by the BEFORE UPDATE trigger.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'appointments'
          AND policyname = 'Patients can update their own appointments'
    ) THEN
        CREATE POLICY "Patients can update their own appointments"
        ON public.appointments
        FOR UPDATE
        TO authenticated
        USING (patient_id = auth.uid())
        WITH CHECK (patient_id = auth.uid());
    END IF;
END $$;

-- ── SEPARATE DOCTOR APPOINTMENT RLS POLICIES ──────────────────────────────

-- DOCTOR SELECT: Doctor can view only appointments assigned to them,
-- requiring an active doctor profile boundary (doctor_profiles.doctor_id = auth.uid()).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'appointments'
          AND policyname = 'Doctors can view their assigned appointments'
    ) THEN
        CREATE POLICY "Doctors can view their assigned appointments"
        ON public.appointments
        FOR SELECT
        TO authenticated
        USING (
            doctor_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM public.doctor_profiles dp
                WHERE dp.doctor_id = auth.uid()
            )
        );
    END IF;
END $$;

-- DOCTOR UPDATE: Doctor can update appointments assigned to them,
-- requiring an active doctor profile boundary (doctor_profiles.doctor_id = auth.uid()).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'appointments'
          AND policyname = 'Doctors can update their assigned appointments'
    ) THEN
        CREATE POLICY "Doctors can update their assigned appointments"
        ON public.appointments
        FOR UPDATE
        TO authenticated
        USING (
            doctor_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM public.doctor_profiles dp
                WHERE dp.doctor_id = auth.uid()
            )
        )
        WITH CHECK (
            doctor_id = auth.uid()
            AND EXISTS (
                SELECT 1 FROM public.doctor_profiles dp
                WHERE dp.doctor_id = auth.uid()
            )
        );
    END IF;
END $$;

-- ── DATABASE TRIGGER: IMMUTABLE FIELDS & ROLE BOUNDARY ENFORCEMENT ─────────
-- Postgres RLS WITH CHECK cannot inspect OLD vs NEW column values.
-- This trigger enforces immutable patient/doctor ownership, fee integrity,
-- and lifecycle transitions directly at the database engine level.

CREATE OR REPLACE FUNCTION public.validate_appointment_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_is_doctor BOOLEAN := false;
BEGIN
    -- Allow service_role to bypass trigger checks
    IF current_user = 'service_role' OR v_uid IS NULL THEN
        NEW.updated_at := now();
        RETURN NEW;
    END IF;

    -- Check if authenticated user is a verified doctor
    SELECT EXISTS (
        SELECT 1 FROM public.doctor_profiles dp WHERE dp.doctor_id = v_uid
    ) INTO v_is_doctor;

    -- 1. PATIENT UPDATE BOUNDARY
    IF v_uid = OLD.patient_id AND NOT (v_uid = OLD.doctor_id AND v_is_doctor) THEN
        -- Prevent changing ownership
        IF NEW.patient_id != OLD.patient_id THEN
            RAISE EXCEPTION 'Patients cannot transfer appointments to another patient.';
        END IF;

        -- Prevent changing doctor
        IF NEW.doctor_id != OLD.doctor_id THEN
            RAISE EXCEPTION 'Patients cannot reassign appointments to a different doctor.';
        END IF;

        -- Prevent changing financial and core metadata
        IF NEW.consultation_fee != OLD.consultation_fee OR
           NEW.platform_fee != OLD.platform_fee OR
           NEW.total_amount != OLD.total_amount OR
           NEW.payment_method != OLD.payment_method OR
           NEW.created_at != OLD.created_at THEN
            RAISE EXCEPTION 'Patients cannot modify appointment fees or creation metadata.';
        END IF;

        -- Prevent marking payment as paid
        IF NEW.payment_status != OLD.payment_status AND NEW.payment_status = 'paid' THEN
            RAISE EXCEPTION 'Patients cannot mark appointment payment status as paid.';
        END IF;

        -- Patient can only change status to 'cancelled' (or leave as 'pending')
        IF NEW.status != OLD.status THEN
            IF NEW.status NOT IN ('cancelled', 'pending') THEN
                RAISE EXCEPTION 'Patients can only cancel pending appointments; cannot confirm or complete them.';
            END IF;
        END IF;

    -- 2. DOCTOR UPDATE BOUNDARY
    ELSIF v_uid = OLD.doctor_id AND v_is_doctor THEN
        -- Prevent changing patient ownership
        IF NEW.patient_id != OLD.patient_id THEN
            RAISE EXCEPTION 'Doctors cannot transfer appointments to another patient.';
        END IF;

        -- Prevent changing doctor ownership
        IF NEW.doctor_id != OLD.doctor_id THEN
            RAISE EXCEPTION 'Doctors cannot transfer appointments to another doctor.';
        END IF;

        -- Prevent changing payment method and created_at
        IF NEW.payment_method != OLD.payment_method OR NEW.created_at != OLD.created_at THEN
            RAISE EXCEPTION 'Doctors cannot alter appointment payment method or creation timestamp.';
        END IF;

    ELSE
        RAISE EXCEPTION 'Unauthorized appointment modification.';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- Attach trigger to public.appointments
DROP TRIGGER IF EXISTS trg_validate_appointment_update ON public.appointments;
CREATE TRIGGER trg_validate_appointment_update
    BEFORE UPDATE ON public.appointments
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_appointment_update();

-- 4. Grant Minimum Required Privileges to Authenticated Role (No Anon Access)
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.doctor_profiles TO authenticated;
GRANT SELECT ON TABLE public.clinics TO authenticated;
GRANT SELECT ON TABLE public.clinic_services TO authenticated;
GRANT SELECT ON TABLE public.doctor_availability TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.appointments TO authenticated;

-- Grant service_role full administrative privileges
GRANT ALL ON TABLE public.doctor_profiles TO service_role;
GRANT ALL ON TABLE public.clinics TO service_role;
GRANT ALL ON TABLE public.clinic_services TO service_role;
GRANT ALL ON TABLE public.doctor_availability TO service_role;
GRANT ALL ON TABLE public.appointments TO service_role;
