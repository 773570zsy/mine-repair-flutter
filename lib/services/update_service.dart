/// 在线更新服务 — IO/Web 条件导入
library update_service;

export 'update_info.dart';
export 'update_service_io.dart' if (dart.library.html) 'update_service_web.dart';
