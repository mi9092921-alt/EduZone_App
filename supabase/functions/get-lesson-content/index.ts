import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Cache-Control': 'private, no-store, max-age=0',
};

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { lesson_id } = await req.json();

    if (!lesson_id) {
      return new Response(JSON.stringify({ error: "Missing lesson_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Create a Supabase client with the Service Role key to bypass RLS for data fetching/signing.
    // However, we still validate the user token manually to ensure security.
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), { 
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: userData, error: userError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));

    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { 
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = userData.user.id;

    // 1. Check access using the RPC we created
    // We pass the user token to a NEW client instance so the RPC runs in the context of the user
    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: access, error: accessError } = await userClient.rpc("check_lesson_access", {
      p_lesson_id: lesson_id,
    });

    if (accessError || !access) {
      return new Response(JSON.stringify({ error: "Access denied" }), { 
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Get video_path (server-side only via service role)
    const { data: content, error: contentError } = await supabase
      .from("lesson_contents")
      .select("video_path, provider, captions_path, duration_sec")
      .eq("lesson_id", lesson_id)
      .single();

    if (contentError || !content) {
      return new Response(JSON.stringify({ error: "Content not found" }), { 
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Generate signed URLs (Valid for 3 minutes to prevent replay attacks)
    let videoUrl = content.video_path;
    let captionsUrl = content.captions_path;

    // Only generate signed URL if it's stored in a bucket (e.g. S3/bunny mapping or local supabase storage)
    // If it's just a youtube ID, we return the ID. Assuming all paths starting with 'lessons/' or similar are Storage objects.
    // Assuming the user's setup uses a 'videos' bucket for actual file hosting.
    if (content.provider !== 'youtube' && content.video_path) {
      const { data: signedVideo } = await supabase.storage
        .from("videos")
        .createSignedUrl(content.video_path, 180);
      
      if (signedVideo) videoUrl = signedVideo.signedUrl;

      if (content.captions_path) {
        const { data: signedCaptions } = await supabase.storage
          .from("videos")
          .createSignedUrl(content.captions_path, 180);
        
        if (signedCaptions) captionsUrl = signedCaptions.signedUrl;
      }
    }

    // 4. Log access
    await supabase.from("audit.lesson_access_log").insert({
      lesson_id: lesson_id,
      user_id: userId,
      access_type: "stream",
      ip_address: req.headers.get('x-forwarded-for') || 'unknown',
    });

    return new Response(
      JSON.stringify({
        has_access: true,
        video_url: videoUrl,
        provider: content.provider,
        duration: content.duration_sec,
        captions_url: captionsUrl,
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  } catch (error: any) {
    console.error("get-lesson-content unexpected failure", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
