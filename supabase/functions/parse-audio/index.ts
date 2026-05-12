import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')!
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

    const { base64Audio, mimeType = 'audio/mp4', userContext = {} } = await req.json()
    if (!base64Audio) throw new Error("Audio tidak ditemukan dalam request.");

    const apiKey = Deno.env.get('GEMINI_API_KEY')

    // Menggunakan Gemini 1.5 Flash (mendukung Multimodal/Audio)
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: `Ekstrak informasi transaksi dari rekaman audio ini ke dalam format JSON murni. Format yang diharapkan: { "type": "income"|"expense"|"transfer", "amount": number, "category": string, "notes": string }. Kategori gunakan bahasa Inggris (contoh: Food, Groceries, Transport). Jangan gunakan markdown \`\`\`json, langsung kembalikan string JSON saja. Konteks user: Target finansial = ${userContext?.financialGoals || 'Tidak ada'}.` },
            { inlineData: { mimeType: mimeType, data: base64Audio } }
          ]
        }]
      })
    })

    const result = await response.json()
    const content = result.candidates[0].content.parts[0].text
    // Sanitasi Markdown JSON
    const cleanJson = content.replace(/^```json\s*/i, "").replace(/```\s*$/i, "").trim()

    return new Response(cleanJson, { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})
