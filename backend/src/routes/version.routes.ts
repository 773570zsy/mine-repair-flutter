import { Router, Request, Response } from 'express';

const router = Router();

// 版本配置（每次发版改这里）
const APP_VERSION = {
  versionCode: 3,
  versionName: '1.0.3',
  downloadUrl: 'https://jlkydds.cn/app/app-release.apk',
  changelog: '- 修复更新弹窗重复弹出\n- 考勤+加班互不冲突\n- 晚检最多3次\n- 部门筛选修复',
  forceUpdate: false,
};

// GET /api/app-version — 客户端检查更新
router.get('/', (_req: Request, res: Response) => {
  res.json({ code: 200, data: APP_VERSION });
});

export default router;
