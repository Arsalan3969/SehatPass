-- ==============================================================================
-- SehatPass Migration: 15-Minute Slot Grid & Availability Validation
-- Migration: 20260904020000_appointment_15min_slot_validation.sql
-- ==============================================================================
-- 1. Updates public.enforce_appointment_service_fee() BEFORE INSERT trigger:
--    - Authoritatively validates target doctor exists and is published (is_published = true)
--    - Authoritatively validates selected service exists, is active, belongs to doctor
--    - Authoritatively validates selected clinic exists, is active, belongs to doctor & matches service
--    - Authoritatively derives consultation_fee and service_name from clinic_services.fee
--    - Authoritatively validates appointment_date is not in the past
--    - Authoritatively validates appointment_date day of week matches an active, published
--      doctor_availability record for the specific doctor and clinic
--    - Authoritatively validates appointment_time aligns with the 15-minute slot grid
--      (:00, :15, :30, :45 and 00 seconds)
--    - Authoritatively validates appointment_time falls within doctor's availability window
--      (start_time to end_time) respecting 15-minute appointment slot duration
--      (i.e. appointment_time >= start_time AND appointment_time + 15 mins <= end_time)
--    - Authoritatively prevents double booking for pending/confirmed appointments
-- 2. Grants and permissions preserved for authenticated patients
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.enforce_appointment_service_fee()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_service RECORD;
    v_avail RECORD;
    v_day_name TEXT;
    v_apt_time TIME;
    v_minute INTEGER;
    v_second INTEGER;
BEGIN
    -- 1. Require valid doctor_id
    IF NEW.doctor_id IS NULL THEN
        RAISE EXCEPTION 'Appointment must have a valid doctor_id.';
    END IF;

    -- Verify target doctor exists and is published
    IF NOT EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = NEW.doctor_id
          AND dp.is_published = true
    ) THEN
        RAISE EXCEPTION 'Target doctor does not exist or is not currently published.';
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

    -- 5. Validate appointment date and time
    IF NEW.appointment_date IS NULL THEN
        RAISE EXCEPTION 'Appointment must have a valid appointment_date.';
    END IF;

    IF NEW.appointment_time IS NULL OR trim(NEW.appointment_time) = '' THEN
        RAISE EXCEPTION 'Appointment must have a valid appointment_time.';
    END IF;

    -- Validate that appointment date is not in the past
    IF NEW.appointment_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Cannot book an appointment for a past date.';
    END IF;

    -- Extract day of week name (e.g. 'Monday', 'Tuesday', ...)
    v_day_name := trim(to_char(NEW.appointment_date, 'Day'));

    -- Find matching doctor availability for doctor, clinic, and day_of_week
    SELECT id, doctor_id, clinic_id, day_of_week, start_time, end_time, is_available
    INTO v_avail
    FROM public.doctor_availability
    WHERE doctor_id = NEW.doctor_id
      AND (clinic_id = NEW.clinic_id OR clinic_id IS NULL)
      AND lower(day_of_week) = lower(v_day_name)
      AND is_available = true
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Doctor has no published availability on % for this clinic.', v_day_name;
    END IF;

    -- Parse appointment_time safely into TIME
    BEGIN
        v_apt_time := NEW.appointment_time::TIME;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid appointment time format: %.', NEW.appointment_time;
    END;

    -- 6. Validate 15-minute grid alignment (e.g. :00, :15, :30, :45 with 00 seconds)
    v_minute := EXTRACT(MINUTE FROM v_apt_time)::INTEGER;
    v_second := EXTRACT(SECOND FROM v_apt_time)::INTEGER;
    IF (v_minute % 15 != 0) OR (v_second != 0) THEN
        RAISE EXCEPTION 'Appointment time % must align with the 15-minute slot grid (e.g. :00, :15, :30, :45).', NEW.appointment_time;
    END IF;

    -- 7. Validate time slot fits within the availability window (15-minute slot duration)
    -- E.g. start_time 09:00:00, end_time 15:00:00 -> slot 09:00 to 14:45 (since 14:45 + 15m = 15:00)
    -- Slot at or after end_time (15:00) or slot before start_time (08:45) is not allowed.
    IF v_apt_time < v_avail.start_time OR (v_apt_time + interval '15 minutes')::TIME > v_avail.end_time THEN
        RAISE EXCEPTION 'Appointment time % is outside doctor''s available hours (% - %) for %.',
            NEW.appointment_time,
            to_char(v_avail.start_time, 'HH12:MI AM'),
            to_char(v_avail.end_time, 'HH12:MI AM'),
            v_day_name;
    END IF;

    -- 8. Check for conflicting pending or confirmed booking (double-booking protection)
    IF EXISTS (
        SELECT 1 FROM public.appointments
        WHERE doctor_id = NEW.doctor_id
          AND appointment_date = NEW.appointment_date
          AND appointment_time = NEW.appointment_time
          AND status IN ('pending', 'confirmed')
    ) THEN
        RAISE EXCEPTION 'This time slot is already booked or requested.';
    END IF;

    -- Initial status must always be pending
    NEW.status := 'pending';
    NEW.created_at := coalesce(NEW.created_at, now());
    NEW.updated_at := now();

    RETURN NEW;
END;
$$;

-- Recreate the trigger on public.appointments
DROP TRIGGER IF EXISTS trg_enforce_appointment_service_fee ON public.appointments;
CREATE TRIGGER trg_enforce_appointment_service_fee
    BEFORE INSERT ON public.appointments
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_appointment_service_fee();
