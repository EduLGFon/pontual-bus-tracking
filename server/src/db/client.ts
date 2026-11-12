// PostgreSQL client. Parameterized tagged templates only, no dynamic SQL.
// See PLAN.md 6.4 and 14.4. Every query touching a device is scoped by id.
import postgres, { type TransactionSql } from "postgres";

export type Sql = ReturnType<typeof postgres>;
/** Open transaction handle passed to sql.begin(). */
export type Tx = TransactionSql<Record<string, unknown>>;

/** Open a client with a tiny pool. Caller must close with sql.end(). */
export function openDb(databaseUrl: string): Sql {
  return postgres(databaseUrl, {
    max: 5,
    idle_timeout: 20,
    connect_timeout: 5,
    infer: true,
  });
}
