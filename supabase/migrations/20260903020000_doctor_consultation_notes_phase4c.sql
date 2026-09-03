-- ==============================================================================
-- SehatPass Migration: Doctor Consultation Notes, Diagnosis & Prescriptions (Phase 4C)
-- ==============================================================================
-- 1. Create or harden public.doctor_consultation_notes table
-- 2. Enforce strict JSONB array structure on prescriptions
-- 3. Tri-party relationship binding (doctor_id, patient_id, appointment_id)
-- 4. Enforce status IN ('confirmed', 'completed') for clinical authoring
-- 5. Immutability triggers for core relation keys and timestamps
-- 6. Row Level Security (RLS) policies for Doctors and Patients
-- 7. Least-privilege authenticated grants (Zero anon privileges, No authenticated DELETE)
-- 8. Atomic save_and_complete_consultation SECURITY DEFINER RPC
-- ==============================================================================

-- 1. Create public.doctor_consultation_notes table if not exists
CREATE TABLE IF NOT EXISTS public.doctor_consultation_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID NOT NULL REFERENCES public.appointments(id) ON DELETE RESTRICT,
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    diagnosis TEXT NULL,
    notes TEXT NULL,
    prescriptions JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure all columns and constraints exist if table was partially created
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS appointment_id UUID REFERENCES public.appointments(id) ON DELETE RESTRICT;
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS doctor_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS patient_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS diagnosis TEXT;
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS prescriptions JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.doctor_consultation_notes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Ensure prescriptions is a valid JSON array
ALTER TABLE public.doctor_consultation_notes DROP CONSTRAINT IF EXISTS chk_prescriptions_is_array;
ALTER TABLE public.doctor_consultation_notes ADD CONSTRAINT chk_prescriptions_is_array
    CHECK (jsonb_typeof(prescriptions) = 'array');

-- Unique index on appointment_id (Strict 1:1 clinical encounter note per appointment)
CREATE UNIQUE INDEX IF NOT EXISTS uq_doctor_consultation_notes_appointment_id
    ON public.doctor_consultation_notes (appointment_id);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_doctor_consultation_notes_doctor_id
    ON public.doctor_consultation_notes (doctor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_doctor_consultation_notes_patient_id
    ON public.doctor_consultation_notes (patient_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_doctor_consultation_notes_appointment_id
    ON public.doctor_consultation_notes (appointment_id);

-- 2. Database Trigger Function: Enforce Tri-Party Integrity & Field Immutability
CREATE OR REPLACE FUNCTION public.validate_consultation_note_mutations()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_apt RECORD;
    v_is_doctor BOOLEAN := false;
BEGIN
    -- Allow service_role to bypass trigger checks
    IF current_user = 'service_role' OR v_uid IS NULL THEN
        NEW.updated_at := now();
        RETURN NEW;
    END IF;

    -- Verify caller is a verified doctor
    SELECT EXISTS (
        SELECT 1 FROM public.doctor_profiles dp WHERE dp.doctor_id = v_uid
    ) INTO v_is_doctor;

    IF NOT v_is_doctor THEN
        RAISE EXCEPTION 'Only verified doctors can author or update consultation notes.';
    END IF;

    -- =========================================================================
    -- INSERT VALIDATION
    -- =========================================================================
    IF TG_OP = 'INSERT' THEN
        -- Force/verify author is the authenticated doctor
        IF NEW.doctor_id IS NULL OR NEW.doctor_id != v_uid THEN
            NEW.doctor_id := v_uid;
        END IF;

        IF NEW.appointment_id IS NULL THEN
            RAISE EXCEPTION 'appointment_id is required for consultation notes.';
        END IF;

        -- Fetch and validate the referenced appointment
        SELECT id, doctor_id, patient_id, status
        INTO v_apt
        FROM public.appointments
        WHERE id = NEW.appointment_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Referenced appointment does not exist.';
        END IF;

        -- Tri-party ownership validation
        IF v_apt.doctor_id != v_uid THEN
            RAISE EXCEPTION 'Doctors can only create consultation notes for their own appointments.';
        END IF;

        -- Authoritative patient_id enforcement: guarantee alignment with appointment
        IF NEW.patient_id IS NULL OR NEW.patient_id != v_apt.patient_id THEN
            NEW.patient_id := v_apt.patient_id;
        END IF;

        -- Appointment lifecycle status validation
        IF v_apt.status NOT IN ('confirmed', 'completed') THEN
            RAISE EXCEPTION 'Consultation notes can only be authored for confirmed or completed appointments (current status: %).', v_apt.status;
        END IF;

        -- Ensure prescriptions JSON is array
        IF jsonb_typeof(NEW.prescriptions) != 'array' THEN
            RAISE EXCEPTION 'Prescriptions must be a valid JSON array.';
        END IF;

        NEW.created_at := now();
        NEW.updated_at := now();
        RETURN NEW;

    -- =========================================================================
    -- UPDATE VALIDATION
    -- =========================================================================
    ELSIF TG_OP = 'UPDATE' THEN
        -- Caller must be the authoring doctor
        IF OLD.doctor_id != v_uid THEN
            RAISE EXCEPTION 'Doctors can only update consultation notes they authored.';
        END IF;

        -- Immutable core relationship & identity keys
        IF NEW.id != OLD.id THEN
            RAISE EXCEPTION 'Cannot modify consultation note ID.';
        END IF;

        IF NEW.appointment_id != OLD.appointment_id THEN
            RAISE EXCEPTION 'Cannot reassign consultation note to a different appointment.';
        END IF;

        IF NEW.doctor_id != OLD.doctor_id THEN
            RAISE EXCEPTION 'Cannot transfer consultation note to a different doctor.';
        END IF;

        IF NEW.patient_id != OLD.patient_id THEN
            RAISE EXCEPTION 'Cannot transfer consultation note to a different patient.';
        END IF;

        IF NEW.created_at != OLD.created_at THEN
            RAISE EXCEPTION 'Cannot alter consultation note creation timestamp.';
        END IF;

        -- Verify appointment status remains confirmed or completed
        SELECT status INTO v_apt
        FROM public.appointments
        WHERE id = OLD.appointment_id;

        IF NOT FOUND OR v_apt.status NOT IN ('confirmed', 'completed') THEN
            RAISE EXCEPTION 'Cannot update consultation notes on cancelled or invalid appointments.';
        END IF;

        -- Ensure prescriptions JSON is array
        IF jsonb_typeof(NEW.prescriptions) != 'array' THEN
            RAISE EXCEPTION 'Prescriptions must be a valid JSON array.';
        END IF;

        NEW.updated_at := now();
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_consultation_note_mutations ON public.doctor_consultation_notes;
CREATE TRIGGER trg_validate_consultation_note_mutations
    BEFORE INSERT OR UPDATE ON public.doctor_consultation_notes
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_consultation_note_mutations();

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.doctor_consultation_notes ENABLE ROW LEVEL SECURITY;

-- 4. Row Level Security Policies

-- DOCTOR SELECT: Doctors can read consultation notes they authored for confirmed/completed appointments
DROP POLICY IF EXISTS "Doctors can view their authored consultation notes" ON public.doctor_consultation_notes;
CREATE POLICY "Doctors can view their authored consultation notes"
ON public.doctor_consultation_notes
FOR SELECT
TO authenticated
USING (
    doctor_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.id = doctor_consultation_notes.appointment_id
          AND a.doctor_id = auth.uid()
          AND a.patient_id = doctor_consultation_notes.patient_id
          AND a.status IN ('confirmed', 'completed')
    )
);

-- DOCTOR INSERT: Doctors can insert consultation notes for their assigned active appointments
DROP POLICY IF EXISTS "Doctors can insert consultation notes for assigned appointments" ON public.doctor_consultation_notes;
CREATE POLICY "Doctors can insert consultation notes for assigned appointments"
ON public.doctor_consultation_notes
FOR INSERT
TO authenticated
WITH CHECK (
    doctor_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.id = doctor_consultation_notes.appointment_id
          AND a.doctor_id = auth.uid()
          AND a.patient_id = doctor_consultation_notes.patient_id
          AND a.status IN ('confirmed', 'completed')
    )
);

-- DOCTOR UPDATE: Doctors can update their own consultation notes for active appointments
DROP POLICY IF EXISTS "Doctors can update their authored consultation notes" ON public.doctor_consultation_notes;
CREATE POLICY "Doctors can update their authored consultation notes"
ON public.doctor_consultation_notes
FOR UPDATE
TO authenticated
USING (
    doctor_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.id = doctor_consultation_notes.appointment_id
          AND a.doctor_id = auth.uid()
          AND a.patient_id = doctor_consultation_notes.patient_id
          AND a.status IN ('confirmed', 'completed')
    )
)
WITH CHECK (
    doctor_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = auth.uid()
    )
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.id = doctor_consultation_notes.appointment_id
          AND a.doctor_id = auth.uid()
          AND a.patient_id = doctor_consultation_notes.patient_id
          AND a.status IN ('confirmed', 'completed')
    )
);

-- PATIENT SELECT: Patients can view consultation notes for their own active appointments
DROP POLICY IF EXISTS "Patients can view their own consultation notes" ON public.doctor_consultation_notes;
CREATE POLICY "Patients can view their own consultation notes"
ON public.doctor_consultation_notes
FOR SELECT
TO authenticated
USING (
    patient_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.id = doctor_consultation_notes.appointment_id
          AND a.patient_id = auth.uid()
          AND a.status IN ('confirmed', 'completed')
    )
);

-- 5. Atomic Save & Complete Consultation Database Function (RPC)
CREATE OR REPLACE FUNCTION public.save_and_complete_consultation(
    p_appointment_id UUID,
    p_diagnosis TEXT,
    p_notes TEXT,
    p_prescriptions JSONB DEFAULT '[]'::jsonb
)
RETURNS public.doctor_consultation_notes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_apt RECORD;
    v_note public.doctor_consultation_notes;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Verify caller is doctor
    IF NOT EXISTS (SELECT 1 FROM public.doctor_profiles WHERE doctor_id = v_uid) THEN
        RAISE EXCEPTION 'Only verified doctors can complete consultations.';
    END IF;

    -- Fetch and lock appointment row
    SELECT id, doctor_id, patient_id, status
    INTO v_apt
    FROM public.appointments
    WHERE id = p_appointment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Appointment % does not exist.', p_appointment_id;
    END IF;

    IF v_apt.doctor_id != v_uid THEN
        RAISE EXCEPTION 'Unauthorized: appointment does not belong to the calling doctor.';
    END IF;

    IF v_apt.status NOT IN ('confirmed', 'completed') THEN
        RAISE EXCEPTION 'Cannot complete consultation for appointment in % status.', v_apt.status;
    END IF;

    IF jsonb_typeof(p_prescriptions) != 'array' THEN
        RAISE EXCEPTION 'Prescriptions must be a valid JSON array.';
    END IF;

    -- 1. Upsert consultation note
    INSERT INTO public.doctor_consultation_notes (
        appointment_id,
        doctor_id,
        patient_id,
        diagnosis,
        notes,
        prescriptions,
        updated_at
    )
    VALUES (
        p_appointment_id,
        v_uid,
        v_apt.patient_id,
        p_diagnosis,
        p_notes,
        p_prescriptions,
        now()
    )
    ON CONFLICT (appointment_id)
    DO UPDATE SET
        diagnosis = EXCLUDED.diagnosis,
        notes = EXCLUDED.notes,
        prescriptions = EXCLUDED.prescriptions,
        updated_at = now()
    RETURNING * INTO v_note;

    -- 2. Mark appointment as completed
    UPDATE public.appointments
    SET status = 'completed',
        updated_at = now()
    WHERE id = p_appointment_id;

    RETURN v_note;
END;
$$;

-- 6. Grant Least-Privilege Permissions (Zero Anon Access, No Authenticated DELETE)
GRANT SELECT, INSERT, UPDATE ON TABLE public.doctor_consultation_notes TO authenticated;
GRANT ALL ON TABLE public.doctor_consultation_notes TO service_role;
GRANT EXECUTE ON FUNCTION public.save_and_complete_consultation(UUID, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_and_complete_consultation(UUID, TEXT, TEXT, JSONB) TO service_role;
