/**
 * Cloud Functions entry point.
 *
 * `./bootstrap` MUST be imported first: it runs `setGlobalOptions` and
 * `initializeApp()` as side effects, and ES modules evaluate imports before
 * the importing module's own body. Importing it first here guarantees those
 * calls run before any trigger module (`./triggers/*`) is evaluated.
 *
 * This file otherwise only re-exports trigger functions. Export names MUST
 * match the deployed function names exactly (`health`, `onItemUpdated`,
 * `onItemDeleted`, `onGroupDeleted`) — renaming an export causes Firebase to
 * delete and recreate the function on deploy.
 */
import "./bootstrap";

export { health } from "./triggers/health";
export { onItemUpdated, onItemDeleted } from "./triggers/items";
export { onGroupDeleted } from "./triggers/groups";
