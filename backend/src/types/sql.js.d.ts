declare module 'sql.js' {
  interface QueryExecResult {
    columns: string[];
    values: unknown[][];
  }

  interface Statement {
    bind(params?: unknown[]): boolean;
    step(): boolean;
    getAsObject(): Record<string, unknown>;
    reset(): void;
    free(): void;
  }

  class Database {
    constructor(data?: ArrayLike<number> | Buffer | null);
    prepare(sql: string): Statement;
    exec(sql: string): QueryExecResult[];
    run(sql: string, params?: unknown[]): Database;
    export(): Uint8Array;
    close(): void;
    getRowsModified(): number;
  }

  interface SqlJsStatic {
    Database: new (data?: ArrayLike<number> | Buffer | null) => Database;
  }

  const initSqlJs: SqlJsStatic;
  export default initSqlJs;
  export { Database, Statement, SqlJsStatic, QueryExecResult };
}
