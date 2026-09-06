-- ==============================================================================
-- SehatPass Migration: Trusted Automatic Doctor Notification Triggers (Phase 2C)
-- ==============================================================================
-- 1. Database-enforced partial unique expression indexes for doctor idempotency
-- 2. Hardened SECURITY DEFINER trigger functions with strict search_path = public, pg_temp
-- 3. Automatic triggers for:
--    - New appointment requested by patient (on INSERT with status = 'pending')
--    - Appointment cancelled by patient (on UPDATE with status = 'cancelled')
--    - Medical report uploaded for an actively assigned patient (on INSERT)
-- 4. Safe patient/doctor cancellation discrimination (Self-action suppression)
-- 5. Privacy preservation: Zero clinical diagnostic leakage in notification message text
-- 6. Strict least-privilege security grants & revokes (No client direct EXECUTE)
-- ==============================================================================

-- 1. Concurrency-Safe Idempotency Indexes on public.notifications
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_doctor_appointment_event
    ON public.notifications (user_id, (payload->>'appointment_id'), (payload->>'event'))
    WHERE type = 'appointment' AND (payload->>'appointment_id') IS NOT NULL AND (payload->>'event') IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_doctor_report_event
    ON public.notifications (user_id, (payload->>'report_id'), (payload->>'event'))
    WHERE type = 'report' AND (payload->>'report_id') IS NOT NULL AND (payload->>'event') IS NOT NULL;


-- 2. Doctor Appointment Notification Trigger Function
CREATE OR REPLACE FUNCTION public.handle_doctor_appointment_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_patient_name TEXT;
    v_date_str TEXT;
    v_is_doctor_action BOOLEAN := false;
BEGIN
    -- Guard: doctor_id must be present
    IF NEW.doctor_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Format date and time safely
    v_date_str := to_char(NEW.appointment_date, 'Mon DD, YYYY') || ' at ' || COALESCE(NEW.appointment_time, 'scheduled time');

    -- Resolve patient name safely from profiles
    SELECT p.full_name INTO v_patient_name
    FROM public.profiles p
    WHERE p.id = NEW.patient_id;

    -- CASE 1: New Appointment Requested by Patient
    -- Fires strictly on INSERT when status is 'pending'
    IF (TG_OP = 'INSERT' AND NEW.status = 'pending') THEN

        INSERT INTO public.notifications (
            user_id,
            title,
            message,
            type,
            is_read,
            payload,
            created_at,
            updated_at
        ) VALUES (
            NEW.doctor_id,
            'New Appointment Request',
            COALESCE(v_patient_name, 'A patient') || ' requested an appointment for ' || COALESCE(NEW.service_name, 'General Consultation') || ' on ' || v_date_str || '.',
            'appointment',
            false,
            jsonb_build_object(
                'appointment_id', NEW.id,
                'event', 'requested',
                'patient_id', NEW.patient_id
            ),
            now(),
            now()
        )
        ON CONFLICT DO NOTHING;

    -- CASE 2: Appointment Cancelled by Patient
    -- Fires strictly on UPDATE when status transitions to 'cancelled'
    ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'cancelled') THEN

        -- Check if cancellation was doctor-initiated:
        -- A. auth.uid() matches doctor_id
        -- B. cancellation_reason indicates doctor decline
        IF (auth.uid() IS NOT NULL AND auth.uid() = NEW.doctor_id) OR
           (COALESCE(NEW.cancellation_reason, '') ILIKE '%declined%') OR
           (COALESCE(NEW.cancellation_reason, '') ILIKE '%doctor%') THEN
            v_is_doctor_action := true;
        END IF;

        -- Only notify doctor if cancellation was patient-initiated (not doctor self-action)
        IF NOT v_is_doctor_action THEN
            INSERT INTO public.notifications (
                user_id,
                title,
                message,
                type,
                is_read,
                payload,
                created_at,
                updated_at
            ) VALUES (
                NEW.doctor_id,
                'Appointment Cancelled',
                'Appointment with ' || COALESCE(v_patient_name, 'patient') || ' on ' || v_date_str || ' has been cancelled by the patient.',
                'appointment',
                false,
                jsonb_build_object(
                    'appointment_id', NEW.id,
                    'event', 'cancelled_by_patient',
                    'patient_id', NEW.patient_id
                ),
                now(),
                now()
            )
            ON CONFLICT DO NOTHING;
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- 3. Doctor Medical Report Notification Trigger Function
CREATE OR REPLACE FUNCTION public.handle_doctor_medical_report_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_doctor_id UUID;
    v_patient_name TEXT;
BEGIN
    IF NEW.patient_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Resolve authoritative doctor recipient with an active confirmed appointment for this patient
    SELECT a.doctor_id INTO v_doctor_id
    FROM public.appointments a
    WHERE a.patient_id = NEW.patient_id
      AND a.status = 'confirmed'
    ORDER BY a.appointment_date DESC, a.created_at DESC
    LIMIT 1;

    -- If no actively confirmed doctor relationship exists, do not send notification
    IF v_doctor_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Resolve patient name safely from profiles
    SELECT p.full_name INTO v_patient_name
    FROM public.profiles p
    WHERE p.id = NEW.patient_id;

    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        is_read,
        payload,
        created_at,
        updated_at
    ) VALUES (
        v_doctor_id,
        'New Patient Report',
        'Patient ' || COALESCE(v_patient_name, 'A patient') || ' uploaded report "' || COALESCE(NEW.title, 'Medical Report') || '".',
        'report',
        false,
        jsonb_build_object(
            'report_id', NEW.id,
            'event', 'patient_report_uploaded',
            'patient_id', NEW.patient_id
        ),
        now(),
        now()
    )
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;


-- 4. Bind Triggers to Tables

-- A. Appointments Doctor Trigger
DROP TRIGGER IF EXISTS trg_doctor_appointment_notification ON public.appointments;
CREATE TRIGGER trg_doctor_appointment_notification
    AFTER INSERT OR UPDATE OF status, cancellation_reason
    ON public.appointments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_doctor_appointment_notification();

-- B. Medical Reports Doctor Trigger
DROP TRIGGER IF EXISTS trg_doctor_medical_report_notification ON public.medical_reports;
CREATE TRIGGER trg_doctor_medical_report_notification
    AFTER INSERT
    ON public.medical_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_doctor_medical_report_notification();


-- 5. Privilege Management (Trigger-only: Revoke direct client RPC execution)
REVOKE ALL ON FUNCTION public.handle_doctor_appointment_notification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_doctor_medical_report_notification() FROM PUBLIC, anon, authenticated;
