import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing edge function environments");
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const supabaseAnonymous = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") || "", {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Verify who is calling
    const { data: userData, error: userError } = await supabaseAnonymous.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized: " + (userError?.message || "") }), { status: 200, headers: corsHeaders });
    }

    // Verify permission manually since this is a highly sensitive endpoint
    // We expect the caller to be an admin with users.write
    const { data: hasPerm, error: permError } = await supabaseAdmin.rpc("user_has_permission", {
      p_user_id: userData.user.id,
      p_permission: "users.manage"
    });

    if (permError) {
       return new Response(JSON.stringify({ error: "permission rpc error: " + permError.message }), { status: 200, headers: corsHeaders });
    }

    if (!hasPerm) {
      // maybe check 'users.write'?
      return new Response(JSON.stringify({ error: "Permission Denied: user lacks users.manage or users.write" }), { status: 200, headers: corsHeaders });
    }

    // Get the admin tenant
    const { data: adminProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("tenant_id")
      .eq("id", userData.user.id)
      .single();

    if (profileError || !adminProfile) {
      return new Response(JSON.stringify({ error: "Could not determine admin tenant ID: " + profileError?.message }), { status: 200, headers: corsHeaders });
    }

    const body = await req.json();
    const { email, password, first_name, last_name, phone, primary_role } = body;

    // 4. Create Auth User
    const { data: authData, error: authCreateError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: password || "Temp1234!", // Fallback temp password
      email_confirm: true,
      user_metadata: {
        first_name,
        last_name,
        phone,
      },
    });

    if (authCreateError) {
      return new Response(JSON.stringify({ error: "Auth create error: " + authCreateError.message }), { status: 200, headers: corsHeaders });
    }

    if (!authData?.user) {
      return new Response(JSON.stringify({ error: "User creation failed silently" }), { status: 200, headers: corsHeaders });
    }

    // 5. Update or Insert the public.users record
    const { error: updateError } = await supabaseAdmin
      .from("users")
      .upsert({
        id: authData.user.id,
        email,
        first_name,
        last_name,
        phone,
        primary_role,
        tenant_id: adminProfile.tenant_id,
      });

    if (updateError) {
      return new Response(JSON.stringify({ error: "User profile sync error: " + updateError.message }), { status: 200, headers: corsHeaders });
    }

    return new Response(JSON.stringify({ success: true, userId: authData.user.id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: "Catch runtime error: " + err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200, // returning 200 to bubble the error json properly
    });
  }
});
