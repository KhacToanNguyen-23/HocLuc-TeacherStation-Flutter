/**
 * Teacher-only stateless tutor MVP (Java 17 HttpClient / Jackson).
 *
 * POST /api/tutor/answer, application/json:
 * {config:{baseUrl,apiKey,model},question,currentPage,lessonSubject?,sources:[{id,label,text}]}.
 * currentPage is an integer 0..100000 (0 means no PDF page).
 * Returns {answer:string,sources:[{id,quote}],status:"answered"|"tentative"|"out_of_scope"|"review",reason:string,
 * confidence:"high"|"low"|"unavailable"}.
 * 200 answered/tentative has reason ""; 200 review has empty answer/sources and reason
 * invalid_evidence or provider_unavailable. Invalid requests: 400 review
 * invalid_request. Forbidden origin/socket: 403 review forbidden_origin.
 * Provider malformed envelopes/JSON are treated as provider_unavailable; no remote details escape.
 *
 * POST /api/tutor/test, application/json: {config:{baseUrl,apiKey,model}}.
 * 200 {success:true} only after an actual max_tokens=8 completion returns exactly OK
 * (surrounding whitespace allowed). Otherwise 502 {success:false,reason:"provider_unavailable"};
 * invalid requests 400 / forbidden origin/socket 403 use success:false and the reasons above.
 * Both routes retain the existing X-Companion-Token interceptor (401 on missing/invalid token).
 * Native requests omit Origin; browser requests must match scheme, serverName and effective port.
 * Socket peers must be literal IPv4/IPv6 loopback; serverName must be a loopback literal
 * or localhost even without Origin, preventing attacker Host DNS rebinding. Forwarded headers ignored.
 *
 * Config: baseUrl <=2048 chars, printable ASCII apiKey <=4096 chars, model <=200 chars.
 * baseUrl is the API root (e.g. https://provider.example/v1); /chat/completions is appended.
 * HTTPS required except literal 127.0.0.1 or ::1 HTTP (localhost hostname is intentionally rejected); no URL userinfo/query/fragment or redirects.
 * Unknown input fields / duplicate JSON fields and trailing JSON rejected. No credentials stored or logged.
 * Incoming body <=65536 bytes; question <=2000 chars; <=6 unique sources; id <=128,
 * label <=256, text <=3000 chars each; answer <=1200 chars; <=4 citations,
 * one quote per source, each 8..1000 chars. All required strings nonblank except apiKey; empty key omits Authorization.
 * High-confidence answer.trim() must equal quotes joined by a single newline. Quotes must be exact complete
 * source sentences, delimited by whitespace after .!? or CJK equivalents, ending in punctuation.
 * Abbreviations/atypical punctuation, formulas and bullet facts without terminal punctuation may fail citation validation.
 * Low-confidence answers allow model inference/general knowledge with optional verified citations, including no source context.
 * The client MUST prepend an uncertainty label on every tentative reply and disclose absent lesson evidence.
 * Both valid branches auto-send without teacher approval. out_of_scope maps to a fixed classroom-scope reply.
 * The frontend maps review/provider failures to a fixed chat notice; only transport ambiguity stays journal-only.
 * Optional lessonSubject and provider scope metadata allow topic classification without hardcoded subject names.
 * Provider confidence is categorical/self-reported, not a calibrated probability of correctness.
 * This structural gate does NOT prove relevance, semantic entailment or correctness of source text.
 * No real-provider quality or live classroom acceptance is implied by mock tests.
 * Connect timeout 4s; entire provider future (headers AND body) capped at 12s; response <=32768 bytes.
 * No fallback provider, persistence, streaming, tool calls or teacher-note enrichment.
 * Limits apply to this route's reads; a client slowly uploading its request is subject to server
 * transport timeout configuration, outside this module's ownership.
 */
package vn.teaching.modules.tutor;
