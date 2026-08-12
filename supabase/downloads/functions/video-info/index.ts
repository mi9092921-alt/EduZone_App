import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE") || "";
const EXTERNAL_API_URL = Deno.env.get("VIDEO_API_URL") || "";
const EXTERNAL_API_KEY = Deno.env.get("VIDEO_API_KEY") || "";
const REPLIT_TIMEOUT_MS = Number(Deno.env.get("VIDEO_REPLIT_TIMEOUT_MS") || 8000);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─── Supabase REST helpers ────────────────────────────────────────────────────

function sbUrl(path: string) {
  return `${SUPABASE_URL.replace(/\/+$/, "")}/rest/v1/${path}`;
}

async function sbGet(path: string) {
  return fetch(sbUrl(path), {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE}`,
      Accept: "application/json",
    },
  });
}

function sbPost(path: string, body: unknown) {
  return fetch(sbUrl(path), {
    method: "POST",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates,return=minimal",
    },
    body: JSON.stringify(body),
  });
}

// ─── URL hash ─────────────────────────────────────────────────────────────────

async function hashUrl(url: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(url));
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

// ─── Normalize ────────────────────────────────────────────────────────────────
// Transforms raw Replit response into the final output shape Flutter expects.
// No wrapper — this IS the response body.

function firstString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function normalizeAudio(rawAudio: any) {
  if (!rawAudio || typeof rawAudio !== "object") return null;

  const url = firstString(
    rawAudio.audio_url,
    rawAudio.url,
    rawAudio.download_url,
    rawAudio.stream_url,
  );
  if (!url) return null;

  return {
    itag: rawAudio.itag ?? null,
    url,
    size_bytes:
      rawAudio.size_bytes ??
      rawAudio.audio_size_bytes ??
      rawAudio.audio_size ??
      rawAudio.size ??
      null,
    ext: rawAudio.ext ?? "m4a",
  };
}

function isRawAudioOnly(format: any): boolean {
  const mime = firstString(format.mime_type, format.mimeType, format.mime) ?? "";
  const type = firstString(format.type, format.kind) ?? "";
  const vcodec = firstString(format.vcodec, format.video_codec, format.videoCodec) ?? "";

  return format.audio_only === true ||
    format.is_audio === true ||
    type.toLowerCase() === "audio" ||
    mime.toLowerCase().startsWith("audio/") ||
    vcodec.toLowerCase() === "none";
}

function hasFormatAudioUrl(format: any): boolean {
  return firstString(format.audio_url, format.audio?.url) != null;
}

function responseNeedsSeparateAudio(data: any): boolean {
  if (!data || data.audio) return false;
  const formats = Array.isArray(data.formats) ? data.formats : [];
  return formats.some(
    (f: any) => f.requires_merge === true || f.has_audio === false,
  );
}

function normalize(raw: any) {
  const rawFormats = raw.formats || raw.streams || [];
  const formats = rawFormats
    .filter((f: any) => !isRawAudioOnly(f))
    .map((f: any) => ({
      itag: f.itag,
      quality: f.quality_label ?? f.quality,
      height: f.height ?? null,
      fps: f.fps ?? null,
      ext: f.ext ?? "mp4",
      size_bytes: f.size_bytes ?? null,
      has_audio: f.has_audio ?? false,
      requires_merge: f.requires_merge ?? !f.has_audio,
      video_url: f.video_url ?? f.url,
      audio_url: firstString(f.audio_url, f.audio?.url),
      audio_size:
        f.audio_size ??
        f.audio_size_bytes ??
        f.audio?.size_bytes ??
        f.audio?.audio_size ??
        null,
      audio_ext: f.audio_ext ?? f.audio?.ext ?? null,
    }));

  const audio =
    normalizeAudio(raw.audio) ??
    normalizeAudio({
      itag: raw.audio_itag,
      url: raw.audio_url,
      size_bytes: raw.audio_size_bytes ?? raw.audio_size,
      ext: raw.audio_ext,
    }) ??
    rawFormats
      .filter((f: any) => isRawAudioOnly(f) || hasFormatAudioUrl(f))
      .map(normalizeAudio)
      .find(Boolean) ??
    null;

  return {
    title: raw.title ?? null,
    thumbnail: raw.thumbnail ?? null,
    duration: raw.duration ?? null,
    channel: raw.channel ?? null,
    view_count: raw.view_count ?? null,
    audio,
    formats,
    default_download_quality: "360p",
    cache_expires_at: new Date(Date.now() + 86400000).toISOString(),
    source: "fresh",
    platform: "YouTube",
    time_ms: 0,       // overwritten before returning
  };
}

// ─── Handler ──────────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startMs = Date.now();

  try {
    // Parse body
    const contentType = req.headers.get("content-type") || "";
    let body: any = {};
    if (contentType.includes("application/json")) {
      body = await req.json();
    } else {
      const text = await req.text();
      if (text) body.url = new URLSearchParams(text).get("url") ?? undefined;
    }

    const videoUrl: string = body?.url;
    if (!videoUrl) {
      return new Response(
        JSON.stringify({ error: "Video URL is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const urlHash = await hashUrl(videoUrl);

    // ── Cache lookup ──────────────────────────────────────────────────────────
    // Always save a stale reference — used as fallback if Replit is down.
    let freshData: any = null;
    let staleData: any = null;

    const cacheRes = await sbGet(
      `video_cache?url_hash=eq.${encodeURIComponent(urlHash)}&select=data,expires_at`,
    );
    if (cacheRes.ok) {
      const rows = await cacheRes.json();
      if (Array.isArray(rows) && rows.length > 0) {
        staleData = rows[0].data;                                          // always keep
        if (rows[0].expires_at && new Date(rows[0].expires_at) > new Date()) {
          freshData = rows[0].data;                                        // valid cache
        }
      }
    }

    // Fresh cache hit → return immediately
    if (freshData && !responseNeedsSeparateAudio(freshData)) {
      return new Response(
        JSON.stringify({ ...freshData, source: "cache", time_ms: Date.now() - startMs }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Fetch from Replit (8s timeout) ────────────────────────────────────────
    const apiUrl = `${EXTERNAL_API_URL.replace(/\/+$/, "")}/info?url=${encodeURIComponent(videoUrl)}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REPLIT_TIMEOUT_MS);

    let normalized: any;
    try {
      const res = await fetch(apiUrl, {
        headers: { "x-api-key": EXTERNAL_API_KEY },
        signal: controller.signal,
      });
      clearTimeout(timer);

      if (!res.ok) throw new Error(`Replit ${res.status}`);

      const raw = await res.json();
      normalized = normalize(raw);
      normalized.time_ms = Date.now() - startMs;

      // Write to cache — best-effort, never blocks the response
      sbPost("video_cache?on_conflict=url_hash", {
        url: videoUrl,
        url_hash: urlHash,
        data: normalized,
        expires_at: normalized.cache_expires_at,
      }).catch(e => console.warn("Cache write failed:", e));

    } catch (fetchErr: any) {
      clearTimeout(timer);

      // Replit down or timed out → serve stale cache if available
      if (staleData && !responseNeedsSeparateAudio(staleData)) {
        console.warn("Replit unavailable, serving stale cache:", fetchErr.message);
        return new Response(
          JSON.stringify({ ...staleData, source: "stale", time_ms: Date.now() - startMs }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // No cache at all
      const msg = fetchErr.name === "AbortError"
        ? "Video server timed out, please try again"
        : "Video server unavailable";
      return new Response(
        JSON.stringify({ error: msg }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify(normalized),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );

  } catch (err: any) {
    console.error("Unhandled error in video-info:", err);
    return new Response(
      JSON.stringify({ error: err?.message || String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
