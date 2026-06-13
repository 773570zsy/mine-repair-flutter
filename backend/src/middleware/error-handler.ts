import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';

/** 自定义业务异常 */
export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string
  ) {
    super(message);
    this.name = 'AppError';
  }
}

/** 统一错误处理中间件 */
export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  logger.error({ err }, 'Unhandled error');

  if (err instanceof AppError) {
    res.status(err.statusCode).json({ code: err.statusCode, msg: err.message });
    return;
  }

  res.status(500).json({ code: 500, msg: '服务器内部错误' });
}

/** 包装异步handler，自动捕获异常 */
export function asyncHandler(fn: (req: Request, res: Response, next: NextFunction) => Promise<void> | void) {
  return (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
