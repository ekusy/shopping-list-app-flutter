import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { getBytes, ref, uploadBytes } from "firebase/storage";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

const PROJECT_ID = "demo-shopping-list-rules-test";
const FIRESTORE_RULES_PATH = resolve(__dirname, "../../../firestore.rules");
const STORAGE_RULES_PATH = resolve(__dirname, "../../../storage.rules");

function parseHostPort(envValue: string | undefined, fallbackHost: string, fallbackPort: number) {
  if (!envValue) return { host: fallbackHost, port: fallbackPort };
  const [host, portStr] = envValue.split(":");
  return { host: host || fallbackHost, port: Number(portStr) || fallbackPort };
}

let testEnv: RulesTestEnvironment;
const smallImage = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);

beforeAll(async () => {
  const fs = parseHostPort(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1", 8080);
  const st = parseHostPort(process.env.FIREBASE_STORAGE_EMULATOR_HOST, "127.0.0.1", 9199);
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: fs.host,
      port: fs.port,
      rules: readFileSync(FIRESTORE_RULES_PATH, "utf8"),
    },
    storage: {
      host: st.host,
      port: st.port,
      rules: readFileSync(STORAGE_RULES_PATH, "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "groups/group-1"), {
      name: "Family",
      ownerId: "alice",
      memberIds: ["alice", "bob"],
    });
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("storage.rules", () => {
  describe("avatars/{uid}", () => {
    it("本人は 1MB 未満の画像を書き込み可、他人は書き込み不可", async () => {
      const aliceStorage = testEnv.authenticatedContext("alice").storage();
      const bobStorage = testEnv.authenticatedContext("bob").storage();
      const unauthStorage = testEnv.unauthenticatedContext().storage();

      await assertSucceeds(
        uploadBytes(ref(aliceStorage, "avatars/alice"), smallImage, {
          contentType: "image/jpeg",
        }),
      );
      await assertSucceeds(getBytes(ref(bobStorage, "avatars/alice")));

      await assertFails(
        uploadBytes(ref(bobStorage, "avatars/alice"), smallImage, {
          contentType: "image/jpeg",
        }),
      );
      await assertFails(
        uploadBytes(ref(aliceStorage, "avatars/alice"), smallImage, {
          contentType: "text/plain",
        }),
      );
      await assertFails(getBytes(ref(unauthStorage, "avatars/alice")));
    });
  });

  describe("groups/{groupId}/items/{fileName}", () => {
    it("グループメンバーは読み書き可、非メンバー・未認証は拒否", async () => {
      const aliceStorage = testEnv.authenticatedContext("alice").storage();
      const bobStorage = testEnv.authenticatedContext("bob").storage();
      const outsiderStorage = testEnv.authenticatedContext("outsider").storage();
      const unauthStorage = testEnv.unauthenticatedContext().storage();

      await assertSucceeds(
        uploadBytes(ref(aliceStorage, "groups/group-1/items/item-1.jpg"), smallImage, {
          contentType: "image/jpeg",
        }),
      );
      await assertSucceeds(
        getBytes(ref(bobStorage, "groups/group-1/items/item-1.jpg")),
      );

      await assertFails(
        uploadBytes(ref(outsiderStorage, "groups/group-1/items/item-2.jpg"), smallImage, {
          contentType: "image/jpeg",
        }),
      );
      await assertFails(
        getBytes(ref(outsiderStorage, "groups/group-1/items/item-1.jpg")),
      );
      await assertFails(
        getBytes(ref(unauthStorage, "groups/group-1/items/item-1.jpg")),
      );
    });
  });

  describe("groups/{groupId}/favoriteItems/{fileName}", () => {
    it("グループメンバーは読み書き可、非メンバーは拒否", async () => {
      const bobStorage = testEnv.authenticatedContext("bob").storage();
      const outsiderStorage = testEnv.authenticatedContext("outsider").storage();

      await assertSucceeds(
        uploadBytes(
          ref(bobStorage, "groups/group-1/favoriteItems/fav-1.jpg"),
          smallImage,
          { contentType: "image/jpeg" },
        ),
      );
      await assertSucceeds(
        getBytes(ref(bobStorage, "groups/group-1/favoriteItems/fav-1.jpg")),
      );

      await assertFails(
        uploadBytes(
          ref(outsiderStorage, "groups/group-1/favoriteItems/fav-2.jpg"),
          smallImage,
          { contentType: "image/jpeg" },
        ),
      );
      await assertFails(
        getBytes(ref(outsiderStorage, "groups/group-1/favoriteItems/fav-1.jpg")),
      );
    });
  });
});
