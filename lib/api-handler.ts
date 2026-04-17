import type { NextApiRequest, NextApiResponse } from 'next';

export interface ApiEnvelope<T = unknown> {
  success: boolean;
  data: T | null;
  error: string | null;
  meta: Record<string, unknown> | null;
}

interface WithApiHandlerOptions {
  allowedMethods: string[];
}

export function withApiHandler(
  handler: (req: NextApiRequest, res: NextApiResponse) => Promise<void>,
  options: WithApiHandlerOptions
) {
  return async (req: NextApiRequest, res: NextApiResponse<ApiEnvelope>) => {
    if (!options.allowedMethods.includes(req.method ?? '')) {
      res.setHeader('Allow', options.allowedMethods);
      return res.status(405).json({
        success: false,
        data: null,
        error: `Method ${req.method} is not supported`,
        meta: null,
      });
    }

    try {
      await handler(req, res);
    } catch {
      return res.status(500).json({
        success: false,
        data: null,
        error: 'Internal server error',
        meta: null,
      });
    }
  };
}
