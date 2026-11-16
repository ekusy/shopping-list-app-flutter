import { defineConfig } from "vitest/config";

// セキュリティルールテスト（test/rules/ 配下）専用設定。
// エミュレータの状態を共有するため直列実行する。
export default defineConfig({
  test: {
    include: ["test/rules/**/*.test.ts"],
    fileParallelism: false,
    testTimeout: 30000,
    hookTimeout: 30000,
  },
});
