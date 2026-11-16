import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from "firebase/firestore";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

const PROJECT_ID = "demo-shopping-list-rules-test";
const RULES_PATH = resolve(__dirname, "../../../firestore.rules");

function parseHostPort(envValue: string | undefined, fallbackHost: string, fallbackPort: number) {
  if (!envValue) return { host: fallbackHost, port: fallbackPort };
  const [host, portStr] = envValue.split(":");
  return { host: host || fallbackHost, port: Number(portStr) || fallbackPort };
}

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  const { host, port } = parseHostPort(process.env.FIRESTORE_EMULATOR_HOST, "127.0.0.1", 8080);
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host,
      port,
      rules: readFileSync(RULES_PATH, "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "groups/group-1"), {
      name: "Family",
      ownerId: "alice",
      memberIds: ["alice", "bob"],
      plan: "free",
    });
    await setDoc(doc(db, "users/alice"), {
      displayName: "Alice",
      groupId: "group-1",
      plan: "free",
    });
    await setDoc(doc(db, "groups/group-1/items/item-1"), {
      name: "牛乳",
      status: "active",
    });
    await setDoc(doc(db, "groups/group-1/favoriteItems/fav-1"), {
      name: "卵",
    });
    await setDoc(doc(db, "groups/group-1/itemHistory/hist-1"), {
      name: "パン",
    });
    await setDoc(doc(db, "groups/group-1/purchaseHistorySummaries/milk"), {
      count: 3,
    });
    await setDoc(doc(db, "groups/group-1/suggestions/2026-W46"), {
      items: ["牛乳"],
    });
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("firestore.rules", () => {
  describe("users/{uid}", () => {
    it("本人は plan フィールドなしで作成・更新できる", async () => {
      const charlieDb = testEnv.authenticatedContext("charlie").firestore();
      await assertSucceeds(
        setDoc(doc(charlieDb, "users/charlie"), { displayName: "Charlie" }),
      );
      await assertSucceeds(
        updateDoc(doc(charlieDb, "users/charlie"), { displayName: "Charlie2" }),
      );
    });

    it("本人が plan / planExpiresAt を設定・変更しようとすると拒否される（#39）", async () => {
      const charlieDb = testEnv.authenticatedContext("charlie").firestore();
      await assertFails(
        setDoc(doc(charlieDb, "users/charlie"), {
          displayName: "Charlie",
          plan: "pro",
        }),
      );

      const aliceDb = testEnv.authenticatedContext("alice").firestore();
      await assertFails(
        updateDoc(doc(aliceDb, "users/alice"), { plan: "pro" }),
      );
      await assertFails(
        updateDoc(doc(aliceDb, "users/alice"), { planExpiresAt: 9999999999 }),
      );
    });

    it("同一グループメンバーは読み取り可、非メンバーは読み取り不可", async () => {
      const bobDb = testEnv.authenticatedContext("bob").firestore();
      const outsiderDb = testEnv.authenticatedContext("outsider").firestore();
      await assertSucceeds(getDoc(doc(bobDb, "users/alice")));
      await assertFails(getDoc(doc(outsiderDb, "users/alice")));
    });
  });

  describe("groups/{groupId}", () => {
    it("メンバーは読み取り可、非メンバー・未認証は拒否", async () => {
      const bobDb = testEnv.authenticatedContext("bob").firestore();
      const outsiderDb = testEnv.authenticatedContext("outsider").firestore();
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      await assertSucceeds(getDoc(doc(bobDb, "groups/group-1")));
      await assertFails(getDoc(doc(outsiderDb, "groups/group-1")));
      await assertFails(getDoc(doc(unauthDb, "groups/group-1")));
    });

    it("グループ作成・更新時に plan / planExpiresAt の変更は拒否される", async () => {
      const bobDb = testEnv.authenticatedContext("bob").firestore();
      await assertFails(
        updateDoc(doc(bobDb, "groups/group-1"), { plan: "pro" }),
      );
      await assertSucceeds(
        updateDoc(doc(bobDb, "groups/group-1"), { name: "Updated Family" }),
      );

      const charlieDb = testEnv.authenticatedContext("charlie").firestore();
      await assertFails(
        setDoc(doc(charlieDb, "groups/group-2"), {
          name: "New",
          ownerId: "charlie",
          memberIds: ["charlie"],
          plan: "pro",
        }),
      );
      await assertSucceeds(
        setDoc(doc(charlieDb, "groups/group-2"), {
          name: "New",
          ownerId: "charlie",
          memberIds: ["charlie"],
        }),
      );
    });
  });

  describe("groups/{groupId}/items/{itemId}", () => {
    it("メンバーは CRUD 可、非メンバー・未認証は拒否", async () => {
      const bobDb = testEnv.authenticatedContext("bob").firestore();
      const outsiderDb = testEnv.authenticatedContext("outsider").firestore();
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      await assertSucceeds(getDoc(doc(bobDb, "groups/group-1/items/item-1")));
      await assertSucceeds(
        setDoc(doc(bobDb, "groups/group-1/items/item-2"), { name: "パン" }),
      );
      await assertSucceeds(
        updateDoc(doc(bobDb, "groups/group-1/items/item-2"), { name: "食パン" }),
      );
      await assertSucceeds(deleteDoc(doc(bobDb, "groups/group-1/items/item-2")));

      await assertFails(getDoc(doc(outsiderDb, "groups/group-1/items/item-1")));
      await assertFails(
        setDoc(doc(outsiderDb, "groups/group-1/items/item-3"), { name: "NG" }),
      );
      await assertFails(getDoc(doc(unauthDb, "groups/group-1/items/item-1")));
    });
  });

  describe("groups/{groupId}/favoriteItems/{favoriteId}", () => {
    it("メンバーは CRUD 可、非メンバーは拒否", async () => {
      const aliceDb = testEnv.authenticatedContext("alice").firestore();
      const outsiderDb = testEnv.authenticatedContext("outsider").firestore();

      await assertSucceeds(
        getDoc(doc(aliceDb, "groups/group-1/favoriteItems/fav-1")),
      );
      await assertSucceeds(
        setDoc(doc(aliceDb, "groups/group-1/favoriteItems/fav-2"), { name: "米" }),
      );
      await assertFails(
        getDoc(doc(outsiderDb, "groups/group-1/favoriteItems/fav-1")),
      );
      await assertFails(
        setDoc(doc(outsiderDb, "groups/group-1/favoriteItems/fav-3"), { name: "NG" }),
      );
    });
  });

  describe("Functions 専用コレクション (itemHistory / purchaseHistorySummaries / suggestions)", () => {
    it("メンバーは読み取り可、クライアントからの書き込みはメンバーでも拒否", async () => {
      const aliceDb = testEnv.authenticatedContext("alice").firestore();
      const outsiderDb = testEnv.authenticatedContext("outsider").firestore();

      await assertSucceeds(
        getDoc(doc(aliceDb, "groups/group-1/itemHistory/hist-1")),
      );
      await assertSucceeds(
        getDoc(doc(aliceDb, "groups/group-1/purchaseHistorySummaries/milk")),
      );
      await assertSucceeds(
        getDoc(doc(aliceDb, "groups/group-1/suggestions/2026-W46")),
      );

      await assertFails(
        setDoc(doc(aliceDb, "groups/group-1/itemHistory/hist-2"), { name: "NG" }),
      );
      await assertFails(
        setDoc(doc(aliceDb, "groups/group-1/purchaseHistorySummaries/bread"), {
          count: 1,
        }),
      );
      await assertFails(
        setDoc(doc(aliceDb, "groups/group-1/suggestions/2026-W47"), {
          items: [],
        }),
      );

      await assertFails(
        getDoc(doc(outsiderDb, "groups/group-1/itemHistory/hist-1")),
      );
      await assertFails(
        getDoc(doc(outsiderDb, "groups/group-1/purchaseHistorySummaries/milk")),
      );
    });
  });
});
