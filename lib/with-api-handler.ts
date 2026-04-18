import type { NextApiRequest, NextApiResponse } from 'next';

interface ApiSuccessResponse<T> {
  success: true;
  data: T;
  error: null;
  meta: Record<string, unknown> | null;
}

interface ApiErrorResponse {
  success: false;
  data: null;
  error: string;
  meta: null;
}

export type ApiResponse<T> = ApiSuccessResponse<T> | ApiErrorResponse;

interface WithApiHandlerOptions {
  allowedMethods: string[];
}

type ApiHandler = (
  req: NextApiRequest,
  res: NextApiResponse
) => Promise<void>;

export function withApiHandler(
  handler: ApiHandler,
  options: WithApiHandlerOptions
) {
  return async (req: NextApiRequest, res: NextApiResponse) => {
    if (!options.allowedMethods.includes(req.method ?? '')) {
      res.setHeader('Allow', options.allowedMethods);
      return res.status(405).json({
        success: false,
        data: null,
        error: `${req.method} is not supported`,
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
