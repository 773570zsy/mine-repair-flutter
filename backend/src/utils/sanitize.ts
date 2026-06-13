/**
 * 输入消毒工具 — 防XSS存储注入
 * 对所有用户输入的文本字段做HTML实体编码
 */

/** HTML实体转义，防止XSS */
export function sanitize(input: string | null | undefined): string {
  if (input == null) return '';
  return String(input)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
}

/** 逐个字段消毒（纯文本/单行输入） */
export function sanitizeStrings<T extends Record<string, unknown>>(
  obj: T,
  fields: (keyof T)[]
): T {
  for (const field of fields) {
    if (typeof obj[field] === 'string') {
      (obj as any)[field] = sanitize(obj[field] as string);
    }
  }
  return obj;
}
