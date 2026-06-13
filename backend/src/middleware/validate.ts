import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';

/** Zod 输入验证中间件工厂 */
export function validate(schema: ZodSchema, source: 'body' | 'query' | 'params' = 'body') {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      const data = schema.parse(req[source]);
      // 替换为解析后的数据（含默认值、类型转换）
      (req as unknown as Record<string, unknown>)[source] = data;
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        const msg = (err as ZodError).issues.map(e => e.message).join('; ');
        res.status(400).json({ code: 400, msg: `参数校验失败: ${msg}` });
        return;
      }
      next(err);
    }
  };
}

export { ZodSchema, ZodError };
