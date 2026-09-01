// ==============================================================================
// SehatPass: Emergency Medical Access Edge Function
// ==============================================================================
// 1. Validates opaque emergency token (UUID)
// 2. Invokes get_public_emergency_info RPC to retrieve emergency-permitted fields only
// 3. Renders a responsive, mobile-friendly HTML Emergency Medical Profile page
//    or JSON response for programmatic inspection
// 4. Zero auth required for responders (designed for instant mobile browser access)
// 5. Zero sensitive private credentials (passwords, JWTs, private files) exposed
// ==============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

interface EmergencyData {
  is_active?: boolean;
  full_name?: string | null;
  date_of_birth?: string | null;
  gender?: string | null;
  blood_group?: string | null;
  allergies?: string | null;
  medical_conditions?: string | null;
  important_medicines?: Array<{
    name: string;
    dosage?: string;
    instruction?: string;
    scheduled_time?: string;
  }>;
  emergency_contact?: {
    name?: string | null;
    relationship?: string | null;
    phone?: string | null;
  } | null;
  updated_at?: string;
}

function escapeHtml(text: string | null | undefined): string {
  if (!text) return "";
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function renderHtmlProfile(data: EmergencyData | null, isValid: boolean): string {
  if (!isValid || !data) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SehatPass - Emergency Profile Unavailable</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background-color: #F8FAFC; color: #1E293B; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }
    .card { background: #FFFFFF; border-radius: 20px; border: 1px solid #E2E8F0; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05); max-width: 480px; width: 100%; padding: 32px 24px; text-align: center; }
    .icon { width: 64px; height: 64px; background: #FEE2E2; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 32px; margin-bottom: 20px; }
    h1 { font-size: 20px; font-weight: 700; color: #991B1B; margin-bottom: 10px; }
    p { font-size: 14px; color: #64748B; line-height: 1.5; margin-bottom: 24px; }
    .footer { font-size: 12px; color: #94A3B8; border-top: 1px solid #F1F5F9; padding-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">🚨</div>
    <h1>Emergency Access Unavailable</h1>
    <p>This Emergency QR code is invalid, disabled, or has been revoked by the patient.</p>
    <div class="footer">SehatPass Emergency Medical Information System</div>
  </div>
</body>
</html>`;
  }

  const name = escapeHtml(data.full_name) || "Not provided";
  const dob = escapeHtml(data.date_of_birth) || "Not provided";
  const gender = escapeHtml(data.gender) || "Not provided";
  const bloodGroup = escapeHtml(data.blood_group) || "Not provided";
  const allergies = escapeHtml(data.allergies) || "Not provided";
  const conditions = escapeHtml(data.medical_conditions) || "Not provided";

  const contactName = escapeHtml(data.emergency_contact?.name) || "Not provided";
  const contactRel = escapeHtml(data.emergency_contact?.relationship) || "Not provided";
  const contactPhone = escapeHtml(data.emergency_contact?.phone) || "";

  const medicines = data.important_medicines || [];

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Emergency Profile - ${name} | SehatPass</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background-color: #0F172A; color: #1E293B; padding: 16px; display: flex; justify-content: center; }
    .container { max-width: 540px; width: 100%; background: #FFFFFF; border-radius: 24px; overflow: hidden; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.3); }
    .header { background: linear-gradient(135deg, #DC2626 0%, #991B1B 100%); color: white; padding: 24px 20px; text-align: center; }
    .header .badge { display: inline-flex; align-items: center; gap: 6px; background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase; margin-bottom: 8px; }
    .header h1 { font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
    .header p { font-size: 13px; opacity: 0.9; margin-top: 4px; }

    .content { padding: 20px; display: flex; flex-direction: column; gap: 16px; }

    .section { background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 16px; padding: 16px; }
    .section-title { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: #64748B; margin-bottom: 12px; display: flex; align-items: center; gap: 6px; }

    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .info-item { display: flex; flex-direction: column; gap: 3px; }
    .info-label { font-size: 11px; color: #64748B; font-weight: 500; }
    .info-value { font-size: 15px; font-weight: 600; color: #0F172A; }

    .blood-badge { display: inline-block; background: #FEE2E2; color: #991B1B; font-size: 20px; font-weight: 800; padding: 4px 16px; border-radius: 12px; border: 1px solid #FECACA; }

    .alert-box { background: #FFFBEB; border: 1px solid #FDE68A; border-radius: 12px; padding: 12px; }
    .alert-box .info-label { color: #B45309; }
    .alert-box .info-value { color: #78350F; }

    .contact-card { background: #EFF6FF; border: 1px solid #BFDBFE; border-radius: 14px; padding: 14px; display: flex; justify-content: space-between; align-items: center; }
    .contact-info { display: flex; flex-direction: column; gap: 2px; }
    .call-btn { background: #2563EB; color: white; text-decoration: none; padding: 8px 16px; border-radius: 10px; font-size: 13px; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }

    .med-item { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 10px; padding: 10px 12px; margin-bottom: 8px; }
    .med-item:last-child { margin-bottom: 0; }
    .med-name { font-size: 14px; font-weight: 600; color: #0F172A; }
    .med-details { font-size: 12px; color: #64748B; margin-top: 2px; }

    .disclaimer { font-size: 11px; color: #94A3B8; text-align: center; line-height: 1.5; padding: 12px 16px 20px; border-top: 1px solid #F1F5F9; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge">🚨 Emergency Access</div>
      <h1>SEHATPASS</h1>
      <p>EMERGENCY MEDICAL PROFILE</p>
    </div>

    <div class="content">
      <!-- Patient Identity -->
      <div class="section">
        <div class="section-title">👤 Patient Identity</div>
        <div class="grid-2">
          <div class="info-item">
            <span class="info-label">Full Name</span>
            <span class="info-value">${name}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Gender</span>
            <span class="info-value">${gender}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Date of Birth / Age</span>
            <span class="info-value">${dob}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Blood Group</span>
            <div><span class="blood-badge">${bloodGroup}</span></div>
          </div>
        </div>
      </div>

      <!-- Emergency Contact -->
      <div class="section">
        <div class="section-title">📞 Emergency Contact</div>
        ${contactPhone ? `
        <div class="contact-card">
          <div class="contact-info">
            <span class="info-value">${contactName}</span>
            <span class="info-label">${contactRel} • ${contactPhone}</span>
          </div>
          <a href="tel:${contactPhone}" class="call-btn">📞 Call Now</a>
        </div>
        ` : `
        <div class="info-item">
          <span class="info-value">${contactName} (${contactRel})</span>
          <span class="info-label">No phone number provided</span>
        </div>
        `}
      </div>

      <!-- Critical Medical Conditions & Allergies -->
      <div class="section">
        <div class="section-title">⚠️ Medical Alerts &amp; Conditions</div>
        <div style="display: flex; flex-direction: column; gap: 10px;">
          <div class="alert-box">
            <div class="info-label">Known Allergies</div>
            <div class="info-value">${allergies}</div>
          </div>
          <div class="alert-box" style="background: #F1F5F9; border-color: #CBD5E1;">
            <div class="info-label" style="color: #475569;">Medical Conditions / Chronic Diseases</div>
            <div class="info-value" style="color: #1E293B;">${conditions}</div>
          </div>
        </div>
      </div>

      <!-- Current Medications -->
      <div class="section">
        <div class="section-title">💊 Current Medications</div>
        ${medicines.length > 0 ? medicines.map(m => `
          <div class="med-item">
            <div class="med-name">${escapeHtml(m.name)} ${m.dosage ? `(${escapeHtml(m.dosage)})` : ''}</div>
            <div class="med-details">${escapeHtml(m.instruction || '')} ${m.scheduled_time ? `• Time: ${escapeHtml(m.scheduled_time)}` : ''}</div>
          </div>
        `).join('') : `
          <div class="info-value" style="font-size: 13px; color: #64748B;">No active medications reported</div>
        `}
      </div>
    </div>

    <div class="disclaimer">
      <strong>Medical Notice:</strong> This emergency profile was provided by the patient through SehatPass. For acute medical emergencies, contact local emergency medical services immediately.
    </div>
  </div>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token") || "";

  const acceptHeader = req.headers.get("Accept") || "";
  const wantsJson = acceptHeader.includes("application/json") || url.searchParams.get("format") === "json";

  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Validate token UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!token || !uuidRegex.test(token.trim())) {
    if (wantsJson) {
      return new Response(JSON.stringify({ error: "Invalid or missing emergency token." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    return new Response(renderHtmlProfile(null, false), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }

  try {
    const envKeys = Object.keys(Deno.env.toObject());
    console.log("[emergency-access] available env keys:", envKeys);

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      "";

    if (!supabaseUrl || !supabaseKey) {
      console.error("[emergency-access] Missing SUPABASE_URL or SUPABASE_ANON_KEY");
      return new Response("Server configuration error", { status: 500 });
    }

    const client = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await client.rpc("get_public_emergency_info", {
      p_token: token.trim(),
    });

    console.log(`[emergency-access] token=${token.trim()} error=${JSON.stringify(error)} data=${JSON.stringify(data)}`);

    if (error || !data || (data as Record<string, unknown>).is_active === false) {
      if (wantsJson) {
        return new Response(JSON.stringify({ error: "Emergency profile not found or inactive.", rpc_error: error, rpc_data: data }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      return new Response(renderHtmlProfile(null, false), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
      });
    }

    const emergencyData = data as EmergencyData;

    if (wantsJson) {
      return new Response(JSON.stringify({ data: emergencyData }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(renderHtmlProfile(emergencyData, true), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  } catch (err) {
    console.error("[emergency-access] Error:", (err as Error).message);
    return new Response(renderHtmlProfile(null, false), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
    });
  }
});
