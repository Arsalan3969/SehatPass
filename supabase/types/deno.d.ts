// Deno ambient definitions for IDE / Language Server support
declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    has(key: string): boolean;
    toObject(): Record<string, string>;
  }

  export const env: Env;

  export function serve(
    handler: (req: Request, info?: any) => Response | Promise<Response>,
  ): any;
  export function serve(
    options: { port?: number; hostname?: string; onListen?: (params: { port: number; hostname: string }) => void; [key: string]: any },
    handler?: (req: Request, info?: any) => Response | Promise<Response>,
  ): any;

  export function readTextFile(path: string | URL, options?: any): Promise<string>;
  export function readTextFileSync(path: string | URL): string;
  export function exit(code?: number): never;
}

interface ImportMeta {
  main: boolean;
  url: string;
}

declare module "@supabase/supabase-js" {
  export interface AuthUser {
    id: string;
    email?: string;
    [key: string]: any;
  }

  export interface AuthResponse {
    data: {
      user: AuthUser | null;
      session?: any;
    };
    error: any;
  }

  export interface PostgrestResponse<T = any> {
    data: T | null;
    error: any;
    count?: number | null;
    status?: number;
    statusText?: string;
  }

  export interface PostgrestFilterBuilder<T = any> extends PromiseLike<PostgrestResponse<T>> {
    select(columns?: string): PostgrestFilterBuilder<T>;
    insert(values: any | any[]): PostgrestFilterBuilder<T>;
    update(values: any): PostgrestFilterBuilder<T>;
    delete(): PostgrestFilterBuilder<T>;
    eq(column: string, value: any): PostgrestFilterBuilder<T>;
    neq(column: string, value: any): PostgrestFilterBuilder<T>;
    order(column: string, options?: { ascending?: boolean; nullsFirst?: boolean; foreignTable?: string }): PostgrestFilterBuilder<T>;
    limit(count: number): PostgrestFilterBuilder<T>;
    maybeSingle(): Promise<PostgrestResponse<T>>;
    single(): Promise<PostgrestResponse<T>>;
  }

  export interface SupabaseClientOptions {
    auth?: {
      persistSession?: boolean;
      autoRefreshToken?: boolean;
      detectSessionInUrl?: boolean;
      storage?: any;
      [key: string]: any;
    };
    global?: {
      headers?: Record<string, string>;
      [key: string]: any;
    };
    [key: string]: any;
  }

  export interface SupabaseClient<Database = any, SchemaName = any, Schema = any> {
    auth: {
      getUser(jwt?: string): Promise<AuthResponse>;
      [key: string]: any;
    };
    from<TableName extends string = string, Row = any>(
      table: TableName
    ): PostgrestFilterBuilder<Row>;
    rpc<Result = any>(
      fn: string,
      args?: Record<string, any>,
      options?: { head?: boolean; count?: 'exact' | 'planned' | 'estimated'; get?: boolean }
    ): Promise<PostgrestResponse<Result>>;
    [key: string]: any;
  }

  export function createClient<Database = any, SchemaName = any, Schema = any>(
    supabaseUrl: string,
    supabaseKey: string,
    options?: SupabaseClientOptions
  ): SupabaseClient<Database, SchemaName, Schema>;
}
