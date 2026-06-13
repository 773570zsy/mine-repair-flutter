import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import multer from 'multer';
import path from 'path';
import fs from 'fs';

const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, Date.now() + '-' + Math.round(Math.random() * 1e9) + ext);
  },
});

const upload = multer({ storage, limits: { fileSize: 20 * 1024 * 1024 } });

const router = Router();

// 单文件上传
router.post('/single', auth, upload.single('file'), asyncHandler(async (req: Request, res: Response) => {
  if (!req.file) { res.json({ code: 400, msg: '请选择文件' }); return; }
  res.json({ code: 200, data: { url: '/uploads/' + req.file.filename, name: req.file.originalname } });
}));

// 多文件上传
router.post('/multiple', auth, upload.array('files', 9), asyncHandler(async (req: Request, res: Response) => {
  const files = req.files as Express.Multer.File[];
  if (!files || files.length === 0) { res.json({ code: 400, msg: '请选择文件' }); return; }
  const urls = files.map(f => ({ url: '/uploads/' + f.filename, name: f.originalname }));
  res.json({ code: 200, data: urls });
}));

export default router;
