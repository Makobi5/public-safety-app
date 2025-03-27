
import { serve } from 'https://deno.land/std@0.204.0/http/server.ts'

// For the Supabase client
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create a Supabase client with the Admin key
    const supabaseAdmin = createClient(
      // Supabase API URL - env var exported by default when deployed
      Deno.env.get('SUPABASE_URL') ?? '',
      // Supabase service role key - env var exported by default when deployed
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get the request body
    const { user_id, new_password } = await req.json()

    // Validate the inputs
    if (!user_id || !new_password) {
      return new Response(
        JSON.stringify({
          error: 'Missing required fields: user_id and new_password are required',
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    // Update the user's password
    const { data, error } = await supabaseAdmin.auth.admin.updateUserById(
      user_id,
      { password: new_password }
    )

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    // Return success
    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})