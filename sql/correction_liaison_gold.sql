SELECT con.conname AS contrainte, a.attname AS colonne
FROM pg_constraint con
JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY (con.conkey)
WHERE con.contype = 'f'
  AND con.conrelid  = 'gold.fact_mandat_fonction'::regclass
  AND con.confrelid = 'gold.dim_date'::regclass;



DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY (con.conkey)
        WHERE con.contype = 'f'
          AND con.conrelid  = 'gold.fact_mandat_fonction'::regclass
          AND con.confrelid = 'gold.dim_date'::regclass
          AND a.attname <> 'sk_date_debut_mandat'
    LOOP
        EXECUTE format('ALTER TABLE gold.fact_mandat_fonction DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;