import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Called by Flutter after a download completes successfully.
// access_expires_at is copied from validate-course-access response.
// Flutter stores it locally and validates offline playback without a server call.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
    )

    const { lesson_id, quality, access_expires_at } = await req.json()

    if (!lesson_id || !quality) {
      return new Response(
        JSON.stringify({ error: 'lesson_id and quality are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Resolve course_id from lesson
    const { data: lesson, error: lessonError } = await supabaseClient
      .from('lessons')
      .select('id, course_id')
      .eq('id', lesson_id)
      .eq('tenant_id', user.user_metadata.tenant_id)
      .single()

    if (lessonError || !lesson) {
      return new Response(
        JSON.stringify({ error: 'Lesson not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Insert download log
    const { error: logError } = await supabaseClient
      .from('download_logs')
      .insert({
        user_id:           user.id,
        lesson_id,
        course_id:         lesson.course_id,
        quality,
        downloaded_at:     new Date().toISOString(),
        access_expires_at: access_expires_at ?? null,
      })

    if (logError) {
      // Download already succeeded — log the error but don't fail the request
      console.error('Log insert failed:', logError)
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})