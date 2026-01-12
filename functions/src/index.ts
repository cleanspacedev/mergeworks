import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

// Simple HTTP function for quick sanity checks
export const helloWorld = onRequest({ region: "us-central1" }, (req, res) => {
  logger.info("helloWorld invoked", { method: req.method, path: req.path });
  res.status(200).json({ ok: true, message: "Hello from Firebase Functions!", ts: Date.now() });
});

// Callable function to test Flutter <-> Functions wiring
export const ping = onCall<{ name?: string }, { message: string; ts: number }>(
  { region: "us-central1" },
  (request) => {
    const name = (request.data?.name || "friend").toString();
    logger.info("ping called", { uid: request.auth?.uid ?? null, name });

    // Example: enforce auth if needed
    // if (!request.auth) throw new HttpsError('unauthenticated', 'Sign-in required');

    return { message: `pong, ${name}`, ts: Date.now() };
  }
);
