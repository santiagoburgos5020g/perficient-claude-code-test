import type { NextApiRequest, NextApiResponse } from 'next';
import type { ZodSchema } from 'zod';

export interface ApiEnvelope<T = unknown> {
  success: boolean;
  data: T | null;
  error: string | null;
  meta: Record<string, unknown> | null;
}

interface ApiHandlerOptions {
  allowedMethods: string[];
  querySchema?: ZodSchema;
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

    if (options.querySchema) {
      const parsed = options.querySchema.safeParse(req.query);
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          data: null,
          error: parsed.error.issues.map((i: { message: string }) => i.message).join('; '),
          meta: null,
        });
      }
      req.query = parsed.data;
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
