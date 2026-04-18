const requiredEnvVars = {
  TODOS_API_URL: process.env.TODOS_API_URL,
} as const;

for (const [key, value] of Object.entries(requiredEnvVars)) {
  if (!value) throw new Error(`Missing required environment variable: ${key}`);
}

export const env = requiredEnvVars as { [K in keyof typeof requiredEnvVars]: string };
