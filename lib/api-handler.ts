import type { NextApiRequest, NextApiResponse } from 'next';

export interface ApiEnvelope<T = unknown> {
  success: boolean;
  data: T | null;
  error: string | null;
  meta: Record<string, unknown> | null;
}

interface ApiHandlerOptions {
  allowedMethods: string[];
}

type ApiRouteHandler = (
  req: NextApiRequest,
  res: NextApiResponse<ApiEnvelope>
) => Promise<void>;

export function withApiHandler(
  handler: ApiRouteHandler,
  options: ApiHandlerOptions
) {
  return async (req: NextApiRequest, res: NextApiResponse<ApiEnvelope>) => {
    if (!options.allowedMethods.includes(req.method ?? '')) {
      res.setHeader('Allow', options.allowedMethods);
      return res.status(405).json({
        success: false,
        data: null,
        error: `Method not allowed: ${req.method} is not supported`,
        meta: null,
      });
    }

    try {
      await handler(req, res);
    } catch (error) {
      console.error('API error:', error);
      return res.status(500).json({
        success: false,
        data: null,
        error: 'Internal server error',
        meta: null,
      });
    }
  };
}
