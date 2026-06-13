const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { auth } = require('../middleware/auth');

// 配置存储
const uploadDir = path.join(__dirname, '..', 'public', 'uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dateDir = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const dir = path.join(uploadDir, dateDir);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname);
    const name = Date.now() + '_' + Math.random().toString(36).substring(2, 8) + ext;
    cb(null, name);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20MB
  fileFilter: function (req, file, cb) {
    const allowed = /\.(jpg|jpeg|png|gif|mp4|avi|mov|webm)$/i;
    if (allowed.test(path.extname(file.originalname))) {
      cb(null, true);
    } else {
      cb(new Error('仅支持 jpg/png/gif/mp4/avi/mov 格式'));
    }
  }
});

// 单文件上传
router.post('/single', auth, upload.single('file'), (req, res) => {
  if (!req.file) return res.json({ code: 400, msg: '请选择文件' });
  const url = '/uploads/' + new Date().toISOString().slice(0, 10).replace(/-/g, '') + '/' + req.file.filename;
  res.json({ code: 200, msg: '上传成功', data: { url: url, name: req.file.originalname, size: req.file.size } });
});

// 多文件上传（最多9张）
router.post('/multiple', auth, upload.array('files', 9), (req, res) => {
  if (!req.files || !req.files.length) return res.json({ code: 400, msg: '请选择文件' });
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const urls = req.files.map(f => '/uploads/' + dateStr + '/' + f.filename);
  res.json({ code: 200, msg: '上传成功', data: { urls: urls, count: urls.length } });
});

module.exports = router;
