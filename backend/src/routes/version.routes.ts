import { Router, Request, Response } from 'express';

const router = Router();

// 版本配置（每次发版改这里）
const APP_VERSION = {
  versionCode: 4,
  versionName: '1.0.4',
  downloadUrl: 'https://jlkyzdds-1439779200.cos.ap-chengdu.myqcloud.com/%E7%9F%BF%E5%B1%B1%E7%BB%B4%E4%BF%AE_Android.apk',
  changelog: '- 📊 申请分析：车型分布+趋势图+车辆排名\n- 🏷️ 用车申请新增费供（甲方/乙方）\n- 🩺 早检：精神状态+劳保用品+血压\n- ❤️ 员工历史血压导出\n- 📋 历史指派查看\n- 🐛 Web端中文显示修复',
  forceUpdate: false,
};

// GET /api/app-version — 客户端检查更新
router.get('/', (_req: Request, res: Response) => {
  res.json({ code: 200, data: APP_VERSION });
});

export default router;
