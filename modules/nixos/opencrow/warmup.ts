// Pi extension: prime the LLM prompt cache on session start.
//
// llama-swap's hooks.on_startup.preload loads the model weights into
// VRAM at boot, but the first user message still pays for processing
// the (long) system prompt. By firing a tiny chat completion against
// the same model with the live system prompt right after session
// start, we populate llama.cpp's prefix KV cache, so pi's first real
// request reuses it and responds quickly.
//
// Configured by the opencrow-local NixOS module. Endpoint base URL
// comes from LLAMA_SWAP_BASE_URL; model defaults to ctx.model.id and
// falls back to OPENCROW_PI_MODEL.

export default function (pi) {
  pi.on("session_start", async (_event, ctx) => {
    const root = process.env.LLAMA_SWAP_BASE_URL;
    if (!root) return;

    const model = ctx.model?.id ?? process.env.OPENCROW_PI_MODEL;
    if (!model) return;

    const systemPrompt = ctx.getSystemPrompt();
    if (!systemPrompt) return;

    const url = `${root.replace(/\/+$/, "")}/v1/chat/completions`;
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: "." },
          ],
          max_tokens: 1,
          stream: false,
          cache_prompt: true,
        }),
      });
      if (!res.ok) {
        console.warn(`warmup: HTTP ${res.status} from ${url}`);
        return;
      }
      // Drain the body so the connection closes cleanly.
      await res.text();
      console.info(`warmup: primed prompt cache for ${model}`);
    } catch (err) {
      console.warn("warmup: request failed", err);
    }
  });
}
