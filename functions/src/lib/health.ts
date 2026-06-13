/**
 * Pure business-logic layer for the `health` Cloud Function.
 *
 * This module has no dependency on `firebase-functions` or any trigger
 * runtime, so it can be unit-tested directly and (in the future) reused
 * from a Dart Cloud Functions implementation without modification.
 */
export interface HealthPayload {
  status: string;
  service: string;
}

export function healthPayload(): HealthPayload {
  return {
    status: "ok",
    service: "shopping-list-app-functions",
  };
}
