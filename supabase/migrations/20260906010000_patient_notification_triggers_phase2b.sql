-- ==============================================================================
-- SehatPass Migration: Trusted Automatic Patient Notification Triggers (Phase 2B)
-- ==============================================================================
-- 1. Database-enforced partial unique expression indexes for guaranteed concurrency-safe idempotency
-- 2. Hardened SECURITY DEFINER trigger functions with strict search_path = public, pg_temp
-- 3. Automatic triggers for:
--    - Appointment confirmed (on INSERT or status transition)
--    - Appointment cancelled (on status transition)
--    - Doctor consultation note created (on INSERT)
--    - Medical report added (on INSERT)
-- 4. Privacy preservation: Zero clinical diagnostic leakage in notification message text
-- 5. Strict least-privilege security grants & revokes (No anon execute)
-- ==============================================================================

-- 1. Concurrency-Safe Idempotency Indexes on public.notifications
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_appointment_event
    ON public.notifications (user_id, (payload->>'appointment_id'), (payload->>'event'))
    WHERE type = 'appointment' AND (payload->>'appointment_id') IS NOT NULL AND (payload->>'event') IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_consultation_id
    ON public.notifications (user_id, (payload->>'consultation_id'))
    WHERE type = 'consultation' AND (payload->>'consultation_id') IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_report_id
    ON public.notifications (user_id, (payload->>'report_id'))
    WHERE type = 'report' AND (payload->>'report_id') IS NOT NULL;


-- 2. Appointment Notification Trigger Function (Confirmed & Cancelled)
CREATE OR REPLACE FUNCTION public.handle_appointment_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_doctor_name TEXT;
    v_date_str TEXT;
BEGIN
    -- Format date and time safely
    v_date_str := to_char(NEW.appointment_date, 'Mon DD, YYYY') || ' at ' || COALESCE(NEW.appointment_time, 'scheduled time');

    -- Resolve doctor name safely
    SELECT p.full_name INTO v_doctor_name
    FROM public.profiles p
    WHERE p.id = NEW.doctor_id;

    -- CASE 1: Appointment Confirmed
    -- Trigger on INSERT with confirmed status, or on UPDATE when status transitions to confirmed
    IF (TG_OP = 'INSERT' AND NEW.status = 'confirmed') OR
       (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'confirmed') THEN
        
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
            NEW.patient_id,
            'Appointment Confirmed',
            'Your appointment with Dr. ' || COALESCE(v_doctor_name, 'Doctor') || ' on ' || v_date_str || ' is confirmed.',
            'appointment',
            false,
            jsonb_build_object(
                'appointment_id', NEW.id,
                'event', 'confirmed'
            ),
            now(),
            now()
        )
        ON CONFLICT DO NOTHING;

    -- CASE 2: Appointment Cancelled
    -- Trigger strictly on UPDATE when status transitions to cancelled
    ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'cancelled') THEN

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
            NEW.patient_id,
            'Appointment Cancelled',
            'Your appointment scheduled for ' || v_date_str || ' has been cancelled.' ||
            CASE 
                WHEN NEW.cancellation_reason IS NOT NULL AND trim(NEW.cancellation_reason) != ''
                THEN ' Reason: ' || trim(NEW.cancellation_reason)
                ELSE ''
            END,
            'appointment',
            false,
            jsonb_build_object(
                'appointment_id', NEW.id,
                'event', 'cancelled'
            ),
            now(),
            now()
        )
        ON CONFLICT DO NOTHING;

    END IF;

    RETURN NEW;
END;
$$;


-- 3. Doctor Consultation Note Notification Trigger Function
CREATE OR REPLACE FUNCTION public.handle_consultation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_doctor_name TEXT;
    v_patient_id UUID;
BEGIN
    -- Authoritatively resolve patient_id from the assigned appointment if not directly present
    v_patient_id := NEW.patient_id;
    IF v_patient_id IS NULL THEN
        SELECT a.patient_id INTO v_patient_id
        FROM public.appointments a
        WHERE a.id = NEW.appointment_id;
    END IF;

    IF v_patient_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Resolve doctor name safely
    SELECT p.full_name INTO v_doctor_name
    FROM public.profiles p
    WHERE p.id = NEW.doctor_id;

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
        v_patient_id,
        'Prescription & Consultation Notes',
        'Dr. ' || COALESCE(v_doctor_name, 'Doctor') || ' has added consultation notes and prescriptions to your health record.',
        'consultation',
        false,
        jsonb_build_object(
            'appointment_id', NEW.appointment_id,
            'consultation_id', NEW.id
        ),
        now(),
        now()
    )
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;


-- 4. Medical Report Notification Trigger Function
CREATE OR REPLACE FUNCTION public.handle_medical_report_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.patient_id IS NULL THEN
        RETURN NEW;
    END IF;

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
        NEW.patient_id,
        'New Medical Report Added',
        'Report "' || NEW.title || '" from ' || COALESCE(NEW.lab_facility, 'Laboratory') || ' has been added to your medical records.',
        'report',
        false,
        jsonb_build_object(
            'report_id', NEW.id
        ),
        now(),
        now()
    )
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;


-- 5. Bind Triggers to Tables

-- A. Appointments Trigger
DROP TRIGGER IF EXISTS trg_appointment_patient_notification ON public.appointments;
CREATE TRIGGER trg_appointment_patient_notification
    AFTER INSERT OR UPDATE OF status, appointment_date, appointment_time, cancellation_reason
    ON public.appointments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_appointment_notification();

-- B. Doctor Consultation Notes Trigger
DROP TRIGGER IF EXISTS trg_consultation_patient_notification ON public.doctor_consultation_notes;
CREATE TRIGGER trg_consultation_patient_notification
    AFTER INSERT ON public.doctor_consultation_notes
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_consultation_notification();

-- C. Medical Reports Trigger
DROP TRIGGER IF EXISTS trg_medical_report_patient_notification ON public.medical_reports;
CREATE TRIGGER trg_medical_report_patient_notification
    AFTER INSERT ON public.medical_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_medical_report_notification();


-- 6. Privilege Management (Trigger-only: Revoke all direct client RPC execution)
REVOKE ALL ON FUNCTION public.handle_appointment_notification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_consultation_notification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_medical_report_notification() FROM PUBLIC, anon, authenticated;
