import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import sharp from 'sharp';
import logger from '../utils/logger';

const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

/** 返回当前年月子目录并确保存在，如 uploads/2026/06/ */
function getMonthDir(): string {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const dir = path.join(uploadDir, String(y), m);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  return dir;
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, getMonthDir()),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const useJpg = ['.jpg', '.jpeg', '.png', '.webp', '.bmp'].includes(ext);
    const outExt = useJpg ? '.jpg' : ext;
    cb(null, Date.now() + '-' + Math.round(Math.random() * 1e9) + outExt);
  },
});

/** 生成相对路径（含年月），如 /uploads/2026/06/xxx.jpg */
function relativePath(fullPath: string): string {
  return '/uploads/' + path.relative(uploadDir, fullPath).replace(/\\/g, '/');
}

const upload = multer({ storage, limits: { fileSize: 20 * 1024 * 1024 } });

const router = Router();

/** 压缩图片：最大 1200px 宽/高，jpeg 质量 75 */
async function compressImage(filePath: string, originalExt: string): Promise<void> {
  const ext = originalExt.toLowerCase();
  if (!['.jpg', '.jpeg', '.png', '.webp', '.bmp'].includes(ext)) return; // 非图片跳过

  const tmpPath = filePath + '.tmp';
  try {
    const pipeline = sharp(filePath)
      .resize(1200, 1200, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 75, progressive: true });
    await pipeline.toFile(tmpPath);
    const origSize = fs.statSync(filePath).size;
    const newSize = fs.statSync(tmpPath).size;
    fs.unlinkSync(filePath);
    fs.renameSync(tmpPath, filePath);
    logger.info({ original: origSize, compressed: newSize, ratio: (newSize / origSize * 100).toFixed(1) + '%' }, 'Image compressed');
  } catch (err) {
    // 压缩失败保留原文件
    if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    logger.warn({ err, file: filePath }, 'Image compression failed, kept original');
  }
}

// 单文件上传
router.post('/single', auth, upload.single('file'), asyncHandler(async (req: Request, res: Response) => {
  if (!req.file) { res.json({ code: 400, msg: '请选择文件' }); return; }
  await compressImage(req.file.path, path.extname(req.file.originalname));
  res.json({ code: 200, data: { url: relativePath(req.file.path), name: req.file.originalname } });
}));

// 多文件上传
router.post('/multiple', auth, upload.array('files', 9), asyncHandler(async (req: Request, res: Response) => {
  const files = req.files as Express.Multer.File[];
  if (!files || files.length === 0) { res.json({ code: 400, msg: '请选择文件' }); return; }
  await Promise.all(files.map(f => compressImage(f.path, path.extname(f.originalname))));
  const urls = files.map(f => ({ url: relativePath(f.path), name: f.originalname }));
  res.json({ code: 200, data: urls });
}));

export default router;
