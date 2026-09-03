-- ==============================================================================
-- SehatPass Migration: Phase 5A — Remove Legacy Appointment Fee Trigger & Function
-- ==============================================================================
-- 1. Safely remove obsolete legacy BEFORE INSERT trigger on public.appointments:
--    - trg_set_appointment_fee
-- 2. Safely remove obsolete legacy trigger function:
--    - public.trg_set_appointment_fee()
-- 3. Ensure NO CASCADE is used.
-- 4. Guarantee ONLY the authoritative trg_enforce_appointment_service_fee trigger
--    remains as the active BEFORE INSERT trigger on public.appointments.
-- ==============================================================================

-- 1. Drop obsolete legacy trigger on public.appointments (NO CASCADE)
DROP TRIGGER IF EXISTS trg_set_appointment_fee ON public.appointments;

-- 2. Drop obsolete legacy trigger function (NO CASCADE)
DROP FUNCTION IF EXISTS public.trg_set_appointment_fee();
