--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.1
-- Dumped by pg_dump version 9.6.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: plpython3u; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: -
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plpython3u;


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: archive_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE archive_status AS ENUM (
    'missing',
    'ongoing',
    'present',
    'corrupted'
);


--
-- Name: TYPE archive_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE archive_status IS 'Status of a given archive';


--
-- Name: bucket; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN bucket AS bytea
	CONSTRAINT bucket_check CHECK ((length(VALUE) = 2));


--
-- Name: sha1; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha1 AS bytea
	CONSTRAINT sha1_check CHECK ((length(VALUE) = 20));


--
-- Name: count_copies(bytea, bytea); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION count_copies(from_id bytea, to_id bytea) RETURNS void
    LANGUAGE sql
    AS $$
    with sample as (
        select content_id, copies from content_archive
        where content_id > from_id and content_id <= to_id
    ), data as (
        select substring(content_id from 19) as bucket, jbe.key as archive
        from sample
        join lateral jsonb_each(copies) jbe on true
        where jbe.value->>'status' = 'present'
    ), bucketed as (
        select bucket, archive, count(*) as count
        from data
        group by bucket, archive
    ) update content_archive_counts cac set
        count = cac.count + bucketed.count
      from bucketed
      where cac.archive = bucketed.archive and cac.bucket = bucketed.bucket;
$$;


--
-- Name: FUNCTION count_copies(from_id bytea, to_id bytea); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION count_copies(from_id bytea, to_id bytea) IS 'Count the objects between from_id and to_id, add the results to content_archive_counts';


--
-- Name: hash_sha1(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION hash_sha1(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
   select encode(digest($1, 'sha1'), 'hex')
$_$;


--
-- Name: FUNCTION hash_sha1(text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION hash_sha1(text) IS 'Compute sha1 hash as text';


--
-- Name: init_content_archive_counts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION init_content_archive_counts() RETURNS void
    LANGUAGE sql
    AS $$
    insert into content_archive_counts (
        select id, decode(lpad(to_hex(bucket), 4, '0'), 'hex')::bucket as bucket, 0 as count
        from archive join lateral generate_series(0, 65535) bucket on true
    ) on conflict (archive, bucket) do nothing;
$$;


--
-- Name: FUNCTION init_content_archive_counts(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION init_content_archive_counts() IS 'Initialize the content archive counts for the registered archives';


--
-- Name: swh_content_archive_missing(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_archive_missing(backend_name text) RETURNS SETOF sha1
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select content_id
        from tmp_content_archive tmp where exists (
            select 1
            from content_archive c
            where tmp.content_id = c.content_id
                and (not c.copies ? backend_name
                     or c.copies @> jsonb_build_object(backend_name, '{"status": "missing"}'::jsonb))
        );
end
$$;


--
-- Name: FUNCTION swh_content_archive_missing(backend_name text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_archive_missing(backend_name text) IS 'Filter missing data from a specific backend';


--
-- Name: swh_content_archive_unknown(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_archive_unknown() RETURNS SETOF sha1
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select content_id
        from tmp_content_archive tmp where not exists (
            select 1
            from content_archive c
            where tmp.content_id = c.content_id
        );
end
$$;


--
-- Name: FUNCTION swh_content_archive_unknown(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_archive_unknown() IS 'Retrieve list of unknown sha1s';


--
-- Name: swh_mktemp_content_archive(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_content_archive() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_content_archive (
        like content_archive including defaults
    ) on commit drop;
    alter table tmp_content_archive drop column copies;
    alter table tmp_content_archive drop column num_present;
$$;


--
-- Name: FUNCTION swh_mktemp_content_archive(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_mktemp_content_archive() IS 'Create temporary table content_archive';


--
-- Name: update_content_archive_counts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION update_content_archive_counts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
        content_id sha1;
        content_bucket bucket;
        copies record;
        old_row content_archive;
        new_row content_archive;
    BEGIN
      -- default values for old or new row depending on trigger type
      if tg_op = 'INSERT' then
          old_row := (null::sha1, '{}'::jsonb, 0);
      else
          old_row := old;
      end if;
      if tg_op = 'DELETE' then
          new_row := (null::sha1, '{}'::jsonb, 0);
      else
          new_row := new;
      end if;

      -- get the content bucket
      content_id := coalesce(old_row.content_id, new_row.content_id);
      content_bucket := substring(content_id from 19)::bucket;

      -- compare copies present in old and new row for each archive type
      FOR copies IN
        select coalesce(o.key, n.key) as archive, o.value->>'status' as old_status, n.value->>'status' as new_status
            from jsonb_each(old_row.copies) o full outer join lateral jsonb_each(new_row.copies) n on o.key = n.key
      LOOP
        -- the count didn't change
        CONTINUE WHEN copies.old_status is distinct from copies.new_status OR
                      (copies.old_status != 'present' AND copies.new_status != 'present');

        update content_archive_counts cac
            set count = count + (case when copies.old_status = 'present' then -1 else 1 end)
            where archive = copies.archive and bucket = content_bucket;
      END LOOP;
      return null;
    END;
$$;


--
-- Name: update_num_present(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION update_num_present() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
    NEW.num_present := (select count(*) from jsonb_each(NEW.copies) where value->>'status' = 'present');
    RETURN new;
    END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE archive (
    id text NOT NULL
);


--
-- Name: TABLE archive; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE archive IS 'Possible archives';


--
-- Name: COLUMN archive.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN archive.id IS 'Short identifier for the archive';


--
-- Name: content_archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_archive (
    content_id sha1 NOT NULL,
    copies jsonb,
    num_present integer
);


--
-- Name: TABLE content_archive; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE content_archive IS 'Referencing the status and whereabouts of a content';


--
-- Name: COLUMN content_archive.content_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive.content_id IS 'content identifier';


--
-- Name: COLUMN content_archive.copies; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive.copies IS 'map archive_id -> { "status": archive_status, "mtime": epoch timestamp }';


--
-- Name: COLUMN content_archive.num_present; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive.num_present IS 'Number of copies marked as present (cache updated via trigger)';


--
-- Name: content_archive_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_archive_counts (
    archive text NOT NULL,
    bucket bucket NOT NULL,
    count bigint
);


--
-- Name: TABLE content_archive_counts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE content_archive_counts IS 'Bucketed count of archive contents';


--
-- Name: COLUMN content_archive_counts.archive; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive_counts.archive IS 'the archive for which we''re counting';


--
-- Name: COLUMN content_archive_counts.bucket; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive_counts.bucket IS 'the bucket of items we''re counting';


--
-- Name: COLUMN content_archive_counts.count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive_counts.count IS 'the number of items counted in the given bucket';


--
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE dbversion (
    version integer NOT NULL,
    release timestamp with time zone,
    description text
);


--
-- Name: TABLE dbversion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE dbversion IS 'Schema update tracking';


--
-- Data for Name: archive; Type: TABLE DATA; Schema: public; Owner: -
--

COPY archive (id) FROM stdin;
uffizi
banco
azure
\.


--
-- Data for Name: content_archive; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content_archive (content_id, copies, num_present) FROM stdin;
\.


--
-- Data for Name: content_archive_counts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content_archive_counts (archive, bucket, count) FROM stdin;
\.


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
6	2017-02-07 18:29:46.298573+01	Work In Progress
\.


--
-- Name: archive archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY archive
    ADD CONSTRAINT archive_pkey PRIMARY KEY (id);


--
-- Name: content_archive_counts content_archive_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_archive_counts
    ADD CONSTRAINT content_archive_counts_pkey PRIMARY KEY (archive, bucket);


--
-- Name: content_archive content_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_archive
    ADD CONSTRAINT content_archive_pkey PRIMARY KEY (content_id);


--
-- Name: dbversion dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: content_archive_num_present_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_archive_num_present_idx ON content_archive USING btree (num_present);


--
-- Name: content_archive update_content_archive_counts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_content_archive_counts AFTER INSERT OR DELETE OR UPDATE ON content_archive FOR EACH ROW EXECUTE PROCEDURE update_content_archive_counts();


--
-- Name: content_archive update_num_present; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_num_present BEFORE INSERT OR UPDATE OF copies ON content_archive FOR EACH ROW EXECUTE PROCEDURE update_num_present();


--
-- Name: content_archive_counts content_archive_counts_archive_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_archive_counts
    ADD CONSTRAINT content_archive_counts_archive_fkey FOREIGN KEY (archive) REFERENCES archive(id);


--
-- PostgreSQL database dump complete
--

