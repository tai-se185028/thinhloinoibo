import path from "path";
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const supabaseUrl =
    process.env.VITE_SUPABASE_URL ||
    process.env.SUPABASE_URL ||
    process.env.NEXT_PUBLIC_SUPABASE_URL ||
    env.VITE_SUPABASE_URL;
  const supabaseKey =
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
    process.env.VITE_SUPABASE_ANON_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    env.VITE_SUPABASE_PUBLISHABLE_KEY ||
    env.VITE_SUPABASE_ANON_KEY;

  return {
    plugins: [
      react(),
      tailwindcss(),
      {
        name: "local-invoice-email-api",
        configureServer(server) {
          server.middlewares.use(
            "/api/send-invoice-email",
            async (req, res) => {
              try {
                for (const name of [
                  "VITE_SUPABASE_URL",
                  "VITE_SUPABASE_PUBLISHABLE_KEY",
                  "GMAIL_USER",
                  "GMAIL_APP_PASSWORD",
                ]) {
                  if (!process.env[name] && env[name])
                    process.env[name] = env[name];
                }
                let body = "";
                for await (const chunk of req) {
                  body += chunk;
                  if (Buffer.byteLength(body) > 4_500_000) {
                    res.statusCode = 413;
                    return res.end(
                      JSON.stringify({ message: "Tệp đính kèm quá lớn." }),
                    );
                  }
                }
                req.body = body ? JSON.parse(body) : {};
                res.status = (code) => {
                  res.statusCode = code;
                  return res;
                };
                res.json = (value) => {
                  res.setHeader("Content-Type", "application/json");
                  res.end(JSON.stringify(value));
                };
                const { default: handler } =
                  await import("./api/send-invoice-email.js");
                await handler(req, res);
              } catch {
                res.statusCode = 400;
                res.end(
                  JSON.stringify({
                    message: "Yêu cầu gửi email không hợp lệ.",
                  }),
                );
              }
            },
          );
        },
      },
    ],
    resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
    define: {
      ...(supabaseUrl
        ? { "import.meta.env.VITE_SUPABASE_URL": JSON.stringify(supabaseUrl) }
        : {}),
      ...(supabaseKey
        ? {
            "import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY":
              JSON.stringify(supabaseKey),
          }
        : {}),
    },
  };
});
