import { defineConfig } from "vitest/config";

// テストは src/ 配下の *.test.ts のみを対象にする。
// tsc のビルド成果物（lib/）を誤って拾わないようにするための明示設定。
export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
  },
});
