import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';

const router = Router();

// 照片来源定义（表 + 字段 + 日期字段 + 标签 + 编号字段）
interface PhotoSource {
  table: string;
  field: string;
  dateField: string;
  type: string;
  label: string;
  group: 'repair' | 'hazard' | 'inspection' | 'other'; // 前端三大分类
  refField: string;  // 工单号/编号字段
}
const PHOTO_SOURCES: PhotoSource[] = [
  { table: 'repair_orders',       field: 'fault_images',  dateField: 'created_at',      type: 'repair',        label: '维修报修',     group: 'repair',     refField: 'id' },
  { table: 'daily_inspections',   field: 'photos',        dateField: 'inspection_date', type: 'inspection',    label: '点检',         group: 'inspection', refField: 'id' },
  { table: 'hazards',             field: 'photos_before', dateField: 'created_at',      type: 'hazard_before', label: '隐患(整改前)', group: 'hazard',     refField: 'id' },
  { table: 'hazards',             field: 'photos_after',  dateField: 'created_at',      type: 'hazard_after',  label: '隐患(整改后)', group: 'hazard',     refField: 'id' },
  { table: 'assessments',         field: 'photos',        dateField: 'created_at',      type: 'assessment',    label: '考核通报',     group: 'hazard',     refField: 'id' },
  { table: 'vehicle_archives',    field: 'photos',        dateField: 'created_at',      type: 'vehicle',       label: '车辆档案',     group: 'other',      refField: 'plate_number' },
  { table: 'repair_progress',     field: 'images',        dateField: 'created_at',      type: 'progress',      label: '维修进度',     group: 'repair',     refField: 'repair_order_id' },
  { table: 'repair_quotes',       field: 'damage_photos', dateField: 'created_at',      type: 'quote_damage',  label: '报价(损坏件)', group: 'repair',     refField: 'repair_order_id' },
  { table: 'repair_quotes',       field: 'new_photos',    dateField: 'created_at',      type: 'quote_new',     label: '报价(新配件)', group: 'repair',     refField: 'repair_order_id' },
  { table: 'external_repair_orders', field: 'fault_images', dateField: 'created_at',   type: 'external',      label: '外部报修',     group: 'repair',     refField: 'id' },
  { table: 'external_repair_progress', field: 'images',   dateField: 'created_at',      type: 'ext_progress',  label: '外部维修进度', group: 'repair',     refField: 'external_order_id' },
  { table: 'machinery_applications', field: 'briefing_files', dateField: 'created_at', type: 'machinery',     label: '工程机械',     group: 'other',      refField: 'id' },
];

/**
 * GET /api/photos/history?start_date=2026-01-01&end_date=2026-06-30&category=repair&page=1&limit=50
 *
 * 聚合查询所有表中的照片，按日期倒序，支持日期范围+分类筛选 + 分页
 * category: repair(维修) | hazard(整改通报) | inspection(点检) | 不传=全部
 */
router.get('/history', auth, asyncHandler(async (req: Request, res: Response) => {
  const startDate = (req.query.start_date as string) || '';
  const endDate = (req.query.end_date as string) || '';
  const category = (req.query.category as string) || '';
  const page = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(Math.max(1, parseInt(req.query.limit as string) || 50), 100);
  const offset = (page - 1) * limit;

  // 筛选来源表（按分类）
  const sources = category
    ? PHOTO_SOURCES.filter(s => s.group === category)
    : PHOTO_SOURCES;

  // 构建日期筛选条件
  let dateWhere = '';
  const params: string[] = [];
  if (startDate || endDate) {
    if (startDate && endDate) {
      dateWhere = `AND date(__DATE_FIELD__) >= ? AND date(__DATE_FIELD__) <= ?`;
      params.push(startDate, endDate);
    } else if (startDate) {
      dateWhere = `AND date(__DATE_FIELD__) >= ?`;
      params.push(startDate);
    } else {
      dateWhere = `AND date(__DATE_FIELD__) <= ?`;
      params.push(endDate);
    }
  }

  const allPhotos: Array<{
    url: string;
    source_type: string;
    source_label: string;
    record_date: string;
    record_id: number;
    order_no: string;
    category: string;
  }> = [];

  const db = getDB();

  for (const src of sources) {
    try {
      const where = dateWhere.replace(/__DATE_FIELD__/g, src.dateField);
      const refCol = src.refField;
      const sql = `SELECT ${src.field} AS photos, ${src.dateField} AS record_date, id AS record_id, ${refCol} AS order_no
                   FROM ${src.table}
                   WHERE ${src.field} IS NOT NULL AND ${src.field} != '' AND ${src.field} != '[]'
                   ${where}`;
      const rows = db.prepare(sql).all(...params) as any[];

      for (const row of rows) {
        try {
          const urls = JSON.parse(row.photos as string);
          if (!Array.isArray(urls)) continue;
          for (const url of urls) {
            if (url && typeof url === 'string' && url.trim()) {
              // 生成可读工单号
              const orderNo = src.type === 'repair' && row.order_no
                ? `WP${String(row.order_no).padStart(6, '0')}`
                : src.type === 'inspection' && row.order_no
                  ? `DJ${String(row.order_no).padStart(6, '0')}`
                  : src.group === 'hazard' && row.order_no
                    ? `YH${String(row.order_no).padStart(6, '0')}`
                    : String(row.order_no || row.record_id);
              allPhotos.push({
                url: url.trim(),
                source_type: src.type,
                source_label: src.label,
                record_date: row.record_date || '',
                record_id: row.record_id,
                order_no: orderNo,
                category: src.group,
              });
            }
          }
        } catch { /* 跳过无效 JSON */ }
      }
    } catch { /* 跳过不存在的表或字段 */ }
  }

  // 按日期倒序
  allPhotos.sort((a, b) => b.record_date.localeCompare(a.record_date));

  // 分页
  const total = allPhotos.length;
  const items = allPhotos.slice(offset, offset + limit);

  res.json({
    code: 200,
    data: { items, total, page, limit, totalPages: Math.ceil(total / limit) },
  });
}));

export default router;
