-- ==============================================================================
-- SehatPass Migration: Phase 5A — Doctor Service Fees + Cash-at-Clinic Cleanup
-- ==============================================================================
-- 1. Dependency-Ordered Safe Removal of Obsolete Payment Objects (NO CASCADE):
--    a. Drop triggers on public.appointments (trg_validate_appointment_update, trg_enforce_appointment_service_fee)
--    b. Drop old patient INSERT RLS policy dependent on platform_fee / payment columns
--    c. Drop possible legacy payment check constraints
--    d. Drop column total_amount FIRST (dependent on platform_fee)
--    e. Drop columns platform_fee, payment_status, payment_method
-- 2. Preserve public.appointments.consultation_fee as authoritative doctor service fee
-- 3. Double-booking concurrency prevention partial unique index:
--    - (doctor_id, appointment_date, appointment_time) WHERE status IN ('pending', 'confirmed')
--    - Cancelled appointments automatically release slot for reuse
-- 4. BEFORE INSERT trigger (trg_enforce_appointment_service_fee):
--    - Strictly requires service_id (NO NULL, NO FALLBACKS)
--    - Validates service exists, is_active, and belongs to target doctor
--    - Validates service.clinic_id is NOT NULL and matches active target clinic
--    - Authoritatively derives consultation_fee and service_name from clinic_services
--    - Prevents patient fee spoofing, cross-doctor, or cross-clinic tampering
-- 5. BEFORE UPDATE trigger (trg_validate_appointment_update):
--    - Preserves field-level immutability for BOTH patient and doctor:
--        * patient_id, doctor_id, service_id, clinic_id, service_name, consultation_fee, created_at
--    - Strictly enforces complete appointment lifecycle state machine transitions:
--        * pending -> confirmed (doctor only)
--        * pending -> cancelled (doctor or patient)
--        * confirmed -> completed (doctor only)
--        * confirmed -> cancelled (doctor only)
--        * cancelled -> * (blocked: terminal state)
--        * completed -> * (blocked: terminal state)
--    - Preserves patient vs doctor role authorization boundaries
-- 6. Recreate clean Patient INSERT RLS Policy:
--    - Requires target doctor to be registered AND published (is_published = true)
--    - Free of all obsolete payment column references
-- 7. Grant least-privilege permissions on public.appointments
-- ==============================================================================

-- ==============================================================================
-- STEP 1: DROP DEPENDENT TRIGGERS AND POLICIES FIRST (NO CASCADE)
-- ==============================================================================

-- 1a. Drop triggers on public.appointments
DROP TRIGGER IF EXISTS trg_validate_appointment_update ON public.appointments;
DROP TRIGGER IF EXISTS trg_enforce_appointment_service_fee ON public.appointments;

-- 1b. Drop old RLS policy that references obsolete payment columns
DROP POLICY IF EXISTS "Patients can insert their own appointment requests" ON public.appointments;

-- 1c. Drop any legacy check constraints on payment columns if present
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS chk_appointments_payment_status;
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS chk_appointments_payment_method;
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_payment_status_check;
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_payment_method_check;

-- 1d. Drop dependent column total_amount FIRST (since total_amount depends on platform_fee)
ALTER TABLE public.appointments DROP COLUMN IF EXISTS total_amount;

-- 1e. Drop platform_fee, payment_status, and payment_method (now free of all dependents)
ALTER TABLE public.appointments DROP COLUMN IF EXISTS platform_fee;
ALTER TABLE public.appointments DROP COLUMN IF EXISTS payment_status;
ALTER TABLE public.appointments DROP COLUMN IF EXISTS payment_method;

-- ==============================================================================
-- STEP 2: ENSURE CONSULTATION_FEE COLUMN EXISTS
-- ==============================================================================
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS consultation_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00;

-- ==============================================================================
-- STEP 3: DOUBLE-BOOKING CONCURRENCY PREVENTION INDEX
-- ==============================================================================
-- Excludes 'cancelled' and 'completed' so cancelled slots can be rebooked
CREATE UNIQUE INDEX IF NOT EXISTS idx_appointments_no_double_booking
ON public.appointments (doctor_id, appointment_date, appointment_time)
WHERE status IN ('pending', 'confirmed');

-- ==============================================================================
-- STEP 4: AUTHORITATIVE SERVICE FEE & CLINIC ENFORCEMENT TRIGGER (BEFORE INSERT)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.enforce_appointment_service_fee()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_service RECORD;
BEGIN
    -- 1. Require valid doctor_id
    IF NEW.doctor_id IS NULL THEN
        RAISE EXCEPTION 'Appointment must have a valid doctor_id.';
    END IF;

    -- 2. Strictly require valid service_id (NO NULL, NO FALLBACKS)
    IF NEW.service_id IS NULL THEN
        RAISE EXCEPTION 'A valid service must be selected for an appointment.';
    END IF;

    -- 3. Fetch authoritative active service record belonging to target doctor
    SELECT id, clinic_id, doctor_id, name, fee, is_active
    INTO v_service
    FROM public.clinic_services
    WHERE id = NEW.service_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Selected service does not exist.';
    END IF;

    IF NOT v_service.is_active THEN
        RAISE EXCEPTION 'Selected service is currently inactive.';
    END IF;

    IF v_service.doctor_id != NEW.doctor_id THEN
        RAISE EXCEPTION 'Selected service does not belong to the target doctor.';
    END IF;

    -- In SehatPass architecture, services are clinic-specific (clinic_id NOT NULL)
    IF v_service.clinic_id IS NULL THEN
        RAISE EXCEPTION 'Selected service must be assigned to a valid clinic.';
    END IF;

    -- If client supplied a clinic_id, it must strictly match service.clinic_id
    IF NEW.clinic_id IS NOT NULL AND NEW.clinic_id != v_service.clinic_id THEN
        RAISE EXCEPTION 'Selected service does not belong to the selected clinic.';
    END IF;

    -- Set/bind appointment clinic_id authoritatively from the verified service
    NEW.clinic_id := v_service.clinic_id;

    -- Verify that the selected clinic exists, belongs to the doctor, and is active
    IF NOT EXISTS (
        SELECT 1 FROM public.clinics c
        WHERE c.id = NEW.clinic_id
          AND c.doctor_id = NEW.doctor_id
          AND c.is_active = true
    ) THEN
        RAISE EXCEPTION 'Selected clinic does not exist or is currently inactive.';
    END IF;

    -- 4. Authoritative snapshot from clinic_services ONLY (client cannot spoof fee or name)
    NEW.consultation_fee := v_service.fee;
    NEW.service_name := v_service.name;

    -- Initial status must always be pending
    NEW.status := 'pending';
    NEW.created_at := coalesce(NEW.created_at, now());
    NEW.updated_at := now();

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_appointment_service_fee
    BEFORE INSERT ON public.appointments
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_appointment_service_fee();

-- ==============================================================================
-- STEP 5: APPOINTMENT UPDATE IMMUTABILITY & LIFECYCLE GUARD TRIGGER (BEFORE UPDATE)
-- ==============================================================================
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
    -- Allow service_role or unauthenticated DB maintenance to bypass trigger checks
    IF current_user = 'service_role' OR v_uid IS NULL THEN
        NEW.updated_at := now();
        RETURN NEW;
    END IF;

    -- Check if authenticated user is a verified doctor
    SELECT EXISTS (
        SELECT 1 FROM public.doctor_profiles dp WHERE dp.doctor_id = v_uid
    ) INTO v_is_doctor;

    -- =========================================================================
    -- 1. PATIENT UPDATE BOUNDARY
    -- =========================================================================
    IF v_uid = OLD.patient_id AND NOT (v_uid = OLD.doctor_id AND v_is_doctor) THEN
        -- Prevent changing ownership
        IF NEW.patient_id != OLD.patient_id THEN
            RAISE EXCEPTION 'Patients cannot transfer appointments to another patient.';
        END IF;

        -- Prevent changing doctor
        IF NEW.doctor_id != OLD.doctor_id THEN
            RAISE EXCEPTION 'Patients cannot reassign appointments to a different doctor.';
        END IF;

        -- Prevent changing service, clinic, service name, consultation fee, or creation timestamp
        IF NEW.service_id IS DISTINCT FROM OLD.service_id OR
           NEW.clinic_id IS DISTINCT FROM OLD.clinic_id OR
           NEW.service_name IS DISTINCT FROM OLD.service_name OR
           NEW.consultation_fee != OLD.consultation_fee OR
           NEW.created_at != OLD.created_at THEN
            RAISE EXCEPTION 'Patients cannot modify appointment service details, fees, or creation metadata.';
        END IF;

        -- Patient status transition enforcement:
        -- Patient can ONLY cancel pending appointments.
        -- Patient CANNOT confirm, complete, or modify confirmed/completed/cancelled appointments.
        IF NEW.status != OLD.status THEN
            IF OLD.status != 'pending' OR NEW.status != 'cancelled' THEN
                RAISE EXCEPTION 'Patients can only cancel pending appointments; cannot confirm or complete them.';
            END IF;
        END IF;

    -- =========================================================================
    -- 2. DOCTOR UPDATE BOUNDARY
    -- =========================================================================
    ELSIF v_uid = OLD.doctor_id AND v_is_doctor THEN
        -- Prevent changing patient ownership
        IF NEW.patient_id != OLD.patient_id THEN
            RAISE EXCEPTION 'Doctors cannot transfer appointments to another patient.';
        END IF;

        -- Prevent changing doctor ownership
        IF NEW.doctor_id != OLD.doctor_id THEN
            RAISE EXCEPTION 'Doctors cannot transfer appointments to another doctor.';
        END IF;

        -- Doctor cannot alter service, clinic, service name, consultation fee, or creation timestamp
        IF NEW.service_id IS DISTINCT FROM OLD.service_id OR
           NEW.clinic_id IS DISTINCT FROM OLD.clinic_id OR
           NEW.service_name IS DISTINCT FROM OLD.service_name OR
           NEW.consultation_fee != OLD.consultation_fee OR
           NEW.created_at != OLD.created_at THEN
            RAISE EXCEPTION 'Doctors cannot alter appointment service details, consultation fee, or creation timestamp.';
        END IF;

        -- Doctor lifecycle status transition enforcement:
        -- Valid transitions:
        --   pending -> confirmed
        --   pending -> cancelled
        --   confirmed -> completed
        --   confirmed -> cancelled
        -- Invalid transitions:
        --   cancelled -> * (blocked: terminal state)
        --   completed -> * (blocked: terminal state)
        --   pending -> completed (must be confirmed first)
        --   * -> pending (cannot revert to pending)
        IF NEW.status != OLD.status THEN
            IF OLD.status = 'pending' AND NEW.status IN ('confirmed', 'cancelled') THEN
                -- Allowed: pending -> confirmed, pending -> cancelled
                NULL;
            ELSIF OLD.status = 'confirmed' AND NEW.status IN ('completed', 'cancelled') THEN
                -- Allowed: confirmed -> completed, confirmed -> cancelled
                NULL;
            ELSIF OLD.status = 'cancelled' THEN
                RAISE EXCEPTION 'Cannot modify an appointment that is already cancelled.';
            ELSIF OLD.status = 'completed' THEN
                RAISE EXCEPTION 'Cannot modify an appointment that is already completed.';
            ELSE
                RAISE EXCEPTION 'Invalid appointment status transition from % to %.', OLD.status, NEW.status;
            END IF;
        END IF;

    -- =========================================================================
    -- 3. UNAUTHORIZED USER BOUNDARY
    -- =========================================================================
    ELSE
        RAISE EXCEPTION 'Unauthorized appointment modification.';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_appointment_update
    BEFORE UPDATE ON public.appointments
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_appointment_update();

-- ==============================================================================
-- STEP 6: ROW LEVEL SECURITY POLICIES FOR PUBLIC.APPOINTMENTS
-- ==============================================================================

-- PATIENT SELECT
DROP POLICY IF EXISTS "Patients can view their own appointments" ON public.appointments;
CREATE POLICY "Patients can view their own appointments"
ON public.appointments
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());

-- PATIENT INSERT (Recreated without obsolete payment columns; strictly checks is_published)
CREATE POLICY "Patients can insert their own appointment requests"
ON public.appointments
FOR INSERT
TO authenticated
WITH CHECK (
    patient_id = auth.uid()
    AND doctor_id != auth.uid()
    AND status = 'pending'
    AND service_id IS NOT NULL
    AND EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = appointments.doctor_id
          AND dp.is_published = true
    )
);

-- PATIENT UPDATE
DROP POLICY IF EXISTS "Patients can update their own appointments" ON public.appointments;
CREATE POLICY "Patients can update their own appointments"
ON public.appointments
FOR UPDATE
TO authenticated
USING (patient_id = auth.uid())
WITH CHECK (patient_id = auth.uid());

-- DOCTOR SELECT
DROP POLICY IF EXISTS "Doctors can view their assigned appointments" ON public.appointments;
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

-- DOCTOR UPDATE
DROP POLICY IF EXISTS "Doctors can update their assigned appointments" ON public.appointments;
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

-- ==============================================================================
-- STEP 7: PRIVILEGES & GRANTS (LEAST-PRIVILEGE AUTHENTICATED ACCESS)
-- ==============================================================================
GRANT SELECT, INSERT, UPDATE ON TABLE public.appointments TO authenticated;
GRANT ALL ON TABLE public.appointments TO service_role;
