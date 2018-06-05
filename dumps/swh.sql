--
-- PostgreSQL database dump
--

-- Dumped from database version 10.4 (Debian 10.4-2.pgdg+1)
-- Dumped by pg_dump version 10.4 (Debian 10.4-2.pgdg+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
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


--
-- Name: blake2s256; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.blake2s256 AS bytea
	CONSTRAINT blake2s256_check CHECK ((length(VALUE) = 32));


--
-- Name: sha1_git; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.sha1_git AS bytea
	CONSTRAINT sha1_git_check CHECK ((length(VALUE) = 20));


--
-- Name: unix_path; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.unix_path AS bytea;


--
-- Name: content_dir; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.content_dir AS (
	directory public.sha1_git,
	path public.unix_path
);


--
-- Name: sha1; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.sha1 AS bytea
	CONSTRAINT sha1_check CHECK ((length(VALUE) = 20));


--
-- Name: sha256; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.sha256 AS bytea
	CONSTRAINT sha256_check CHECK ((length(VALUE) = 32));


--
-- Name: content_signature; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.content_signature AS (
	sha1 public.sha1,
	sha1_git public.sha1_git,
	sha256 public.sha256,
	blake2s256 public.blake2s256
);


--
-- Name: content_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.content_status AS ENUM (
    'absent',
    'visible',
    'hidden'
);


--
-- Name: TYPE content_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.content_status IS 'Content visibility';


--
-- Name: counter; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.counter AS (
	label text,
	value bigint
);


--
-- Name: directory_entry_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.directory_entry_type AS ENUM (
    'file',
    'dir',
    'rev'
);


--
-- Name: file_perms; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.file_perms AS integer;


--
-- Name: directory_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.directory_entry AS (
	dir_id public.sha1_git,
	type public.directory_entry_type,
	target public.sha1_git,
	name public.unix_path,
	perms public.file_perms,
	status public.content_status,
	sha1 public.sha1,
	sha1_git public.sha1_git,
	sha256 public.sha256,
	length bigint
);


--
-- Name: entity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entity_type AS ENUM (
    'organization',
    'group_of_entities',
    'hosting',
    'group_of_persons',
    'person',
    'project'
);


--
-- Name: TYPE entity_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.entity_type IS 'Entity types';


--
-- Name: entity_id; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entity_id AS (
	id bigint,
	uuid uuid,
	parent uuid,
	name text,
	type public.entity_type,
	description text,
	homepage text,
	active boolean,
	generated boolean,
	lister_metadata jsonb,
	metadata jsonb,
	last_seen timestamp with time zone,
	last_id bigint
);


--
-- Name: object_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.object_type AS ENUM (
    'content',
    'directory',
    'revision',
    'release',
    'snapshot'
);


--
-- Name: TYPE object_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.object_type IS 'Data object types stored in data model';


--
-- Name: origin_metadata_signature; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.origin_metadata_signature AS (
	id bigint,
	origin_id bigint,
	discovery_date timestamp with time zone,
	tool_id bigint,
	metadata jsonb,
	provider_id integer,
	provider_name text,
	provider_type text,
	provider_url text
);


--
-- Name: origin_visit_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.origin_visit_status AS ENUM (
    'ongoing',
    'full',
    'partial'
);


--
-- Name: TYPE origin_visit_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.origin_visit_status IS 'Possible visit status';


--
-- Name: release_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.release_entry AS (
	id public.sha1_git,
	target public.sha1_git,
	target_type public.object_type,
	date timestamp with time zone,
	date_offset smallint,
	date_neg_utc_offset boolean,
	name bytea,
	comment bytea,
	synthetic boolean,
	author_id bigint,
	author_fullname bytea,
	author_name bytea,
	author_email bytea,
	object_id bigint
);


--
-- Name: revision_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.revision_type AS ENUM (
    'git',
    'tar',
    'dsc',
    'svn',
    'hg'
);


--
-- Name: TYPE revision_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.revision_type IS 'Possible revision types';


--
-- Name: revision_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.revision_entry AS (
	id public.sha1_git,
	date timestamp with time zone,
	date_offset smallint,
	date_neg_utc_offset boolean,
	committer_date timestamp with time zone,
	committer_date_offset smallint,
	committer_date_neg_utc_offset boolean,
	type public.revision_type,
	directory public.sha1_git,
	message bytea,
	author_id bigint,
	author_fullname bytea,
	author_name bytea,
	author_email bytea,
	committer_id bigint,
	committer_fullname bytea,
	committer_name bytea,
	committer_email bytea,
	metadata jsonb,
	synthetic boolean,
	parents bytea[],
	object_id bigint
);


--
-- Name: snapshot_target; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.snapshot_target AS ENUM (
    'content',
    'directory',
    'revision',
    'release',
    'snapshot',
    'alias'
);


--
-- Name: TYPE snapshot_target; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.snapshot_target IS 'Types of targets for snapshot branches';


--
-- Name: snapshot_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.snapshot_result AS (
	snapshot_id public.sha1_git,
	name bytea,
	target bytea,
	target_type public.snapshot_target
);


--
-- Name: hash_sha1(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hash_sha1(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
   select encode(digest($1, 'sha1'), 'hex')
$_$;


--
-- Name: FUNCTION hash_sha1(text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.hash_sha1(text) IS 'Compute SHA1 hash as text';


--
-- Name: notify_new_content(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_content() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_content', json_build_object(
      'sha1', encode(new.sha1, 'hex'),
      'sha1_git', encode(new.sha1_git, 'hex'),
      'sha256', encode(new.sha256, 'hex'),
      'blake2s256', encode(new.blake2s256, 'hex')
    )::text);
    return null;
  end;
$$;


--
-- Name: notify_new_directory(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_directory() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_directory', json_build_object('id', encode(new.id, 'hex'))::text);
    return null;
  end;
$$;


--
-- Name: notify_new_origin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_origin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_origin', json_build_object('id', new.id)::text);
    return null;
  end;
$$;


--
-- Name: notify_new_origin_visit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_origin_visit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_origin_visit', json_build_object(
      'origin', new.origin,
      'visit', new.visit
    )::text);
    return null;
  end;
$$;


--
-- Name: notify_new_release(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_release', json_build_object('id', encode(new.id, 'hex'))::text);
    return null;
  end;
$$;


--
-- Name: notify_new_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_revision() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_revision', json_build_object('id', encode(new.id, 'hex'))::text);
    return null;
  end;
$$;


--
-- Name: notify_new_skipped_content(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_skipped_content() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_skipped_content', json_build_object(
      'sha1', encode(new.sha1, 'hex'),
      'sha1_git', encode(new.sha1_git, 'hex'),
      'sha256', encode(new.sha256, 'hex'),
      'blake2s256', encode(new.blake2s256, 'hex')
    )::text);
    return null;
  end;
$$;


--
-- Name: swh_content_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_content_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into content (sha1, sha1_git, sha256, blake2s256, length, status)
        select distinct sha1, sha1_git, sha256, blake2s256, length, status from tmp_content;
    return;
end
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content (
    sha1 public.sha1 NOT NULL,
    sha1_git public.sha1_git NOT NULL,
    sha256 public.sha256 NOT NULL,
    blake2s256 public.blake2s256,
    length bigint NOT NULL,
    ctime timestamp with time zone DEFAULT now() NOT NULL,
    status public.content_status DEFAULT 'visible'::public.content_status NOT NULL,
    object_id bigint NOT NULL
);


--
-- Name: swh_content_find(public.sha1, public.sha1_git, public.sha256, public.blake2s256); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_content_find(sha1 public.sha1 DEFAULT NULL::bytea, sha1_git public.sha1_git DEFAULT NULL::bytea, sha256 public.sha256 DEFAULT NULL::bytea, blake2s256 public.blake2s256 DEFAULT NULL::bytea) RETURNS public.content
    LANGUAGE plpgsql
    AS $$
declare
    con content;
    filters text[] := array[] :: text[];  -- AND-clauses used to filter content
    q text;
begin
    if sha1 is not null then
        filters := filters || format('sha1 = %L', sha1);
    end if;
    if sha1_git is not null then
        filters := filters || format('sha1_git = %L', sha1_git);
    end if;
    if sha256 is not null then
        filters := filters || format('sha256 = %L', sha256);
    end if;
    if blake2s256 is not null then
        filters := filters || format('blake2s256 = %L', blake2s256);
    end if;

    if cardinality(filters) = 0 then
        return null;
    else
        q = format('select * from content where %s',
                   array_to_string(filters, ' and '));
        execute q into con;
	return con;
    end if;
end
$$;


--
-- Name: swh_content_find_directory(public.sha1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_content_find_directory(content_id public.sha1) RETURNS public.content_dir
    LANGUAGE sql STABLE
    AS $$
    with recursive path as (
	-- Recursively build a path from the requested content to a root
	-- directory. Each iteration returns a pair (dir_id, filename) where
	-- filename is relative to dir_id. Stops when no parent directory can
	-- be found.
	(select dir.id as dir_id, dir_entry_f.name as name, 0 as depth
	 from directory_entry_file as dir_entry_f
	 join content on content.sha1_git = dir_entry_f.target
	 join directory as dir on dir.file_entries @> array[dir_entry_f.id]
	 where content.sha1 = content_id
	 limit 1)
	union all
	(select dir.id as dir_id,
		(dir_entry_d.name || '/' || path.name)::unix_path as name,
		path.depth + 1
	 from path
	 join directory_entry_dir as dir_entry_d on dir_entry_d.target = path.dir_id
	 join directory as dir on dir.dir_entries @> array[dir_entry_d.id]
	 limit 1)
    )
    select dir_id, name from path order by depth desc limit 1;
$$;


--
-- Name: swh_content_list_by_object_id(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_content_list_by_object_id(min_excl bigint, max_incl bigint) RETURNS SETOF public.content
    LANGUAGE sql STABLE
    AS $$
    select * from content
    where object_id > min_excl and object_id <= max_incl
    order by object_id;
$$;


--
-- Name: swh_content_update(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_content_update(columns_update text[]) RETURNS void
    LANGUAGE plpgsql
    AS $_$
declare
   query text;
   tmp_array text[];
begin
    if array_length(columns_update, 1) = 0 then
        raise exception 'Please, provide the list of column names to update.';
    end if;

    tmp_array := array(select format('%1$s=t.%1$s', unnest) from unnest(columns_update));

    query = format('update content set %s
                    from tmp_content t where t.sha1 = content.sha1',
                    array_to_string(tmp_array, ', '));

    execute query;

    return;
end
$_$;


--
-- Name: FUNCTION swh_content_update(columns_update text[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.swh_content_update(columns_update text[]) IS 'Update existing content''s columns';


--
-- Name: swh_directory_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_directory_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    perform swh_directory_entry_add('file');
    perform swh_directory_entry_add('dir');
    perform swh_directory_entry_add('rev');

    insert into directory
    select * from tmp_directory t
    where not exists (
        select 1 from directory d
	where d.id = t.id);

    return;
end
$$;


--
-- Name: swh_directory_entry_add(public.directory_entry_type); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_directory_entry_add(typ public.directory_entry_type) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
    execute format('
    insert into directory_entry_%1$s (target, name, perms)
    select distinct t.target, t.name, t.perms
    from tmp_directory_entry_%1$s t
    where not exists (
    select 1
    from directory_entry_%1$s i
    where t.target = i.target and t.name = i.name and t.perms = i.perms)
   ', typ);

    execute format('
    with new_entries as (
	select t.dir_id, array_agg(i.id) as entries
	from tmp_directory_entry_%1$s t
	inner join directory_entry_%1$s i
	using (target, name, perms)
	group by t.dir_id
    )
    update tmp_directory as d
    set %1$s_entries = new_entries.entries
    from new_entries
    where d.id = new_entries.dir_id
    ', typ);

    return;
end
$_$;


--
-- Name: swh_directory_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_directory_missing() RETURNS SETOF public.sha1_git
    LANGUAGE plpgsql
    AS $$
begin
    return query
	select id from tmp_directory t
	where not exists (
	    select 1 from directory d
	    where d.id = t.id);
    return;
end
$$;


--
-- Name: swh_directory_walk(public.sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_directory_walk(walked_dir_id public.sha1_git) RETURNS SETOF public.directory_entry
    LANGUAGE sql STABLE
    AS $$
    with recursive entries as (
        select dir_id, type, target, name, perms, status, sha1, sha1_git,
               sha256, length
        from swh_directory_walk_one(walked_dir_id)
        union all
        select dir_id, type, target, (dirname || '/' || name)::unix_path as name,
               perms, status, sha1, sha1_git, sha256, length
        from (select (swh_directory_walk_one(dirs.target)).*, dirs.name as dirname
              from (select target, name from entries where type = 'dir') as dirs) as with_parent
    )
    select dir_id, type, target, name, perms, status, sha1, sha1_git, sha256, length
    from entries
$$;


--
-- Name: swh_directory_walk_one(public.sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_directory_walk_one(walked_dir_id public.sha1_git) RETURNS SETOF public.directory_entry
    LANGUAGE sql STABLE
    AS $$
    with dir as (
	select id as dir_id, dir_entries, file_entries, rev_entries
	from directory
	where id = walked_dir_id),
    ls_d as (select dir_id, unnest(dir_entries) as entry_id from dir),
    ls_f as (select dir_id, unnest(file_entries) as entry_id from dir),
    ls_r as (select dir_id, unnest(rev_entries) as entry_id from dir)
    (select dir_id, 'dir'::directory_entry_type as type,
            e.target, e.name, e.perms, NULL::content_status,
            NULL::sha1, NULL::sha1_git, NULL::sha256, NULL::bigint
     from ls_d
     left join directory_entry_dir e on ls_d.entry_id = e.id)
    union
    (select dir_id, 'file'::directory_entry_type as type,
            e.target, e.name, e.perms, c.status,
            c.sha1, c.sha1_git, c.sha256, c.length
     from ls_f
     left join directory_entry_file e on ls_f.entry_id = e.id
     left join content c on e.target = c.sha1_git)
    union
    (select dir_id, 'rev'::directory_entry_type as type,
            e.target, e.name, e.perms, NULL::content_status,
            NULL::sha1, NULL::sha1_git, NULL::sha256, NULL::bigint
     from ls_r
     left join directory_entry_rev e on ls_r.entry_id = e.id)
    order by name;
$$;


--
-- Name: swh_entity_from_tmp_entity_lister(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_entity_from_tmp_entity_lister() RETURNS SETOF public.entity_id
    LANGUAGE plpgsql
    AS $$
begin
  return query
    select t.id, e.*
    from tmp_entity_lister t
    left join entity e
    on e.lister_metadata @> t.lister_metadata;
  return;
end
$$;


--
-- Name: entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity (
    uuid uuid NOT NULL,
    parent uuid,
    name text NOT NULL,
    type public.entity_type NOT NULL,
    description text,
    homepage text,
    active boolean NOT NULL,
    generated boolean NOT NULL,
    lister_metadata jsonb,
    metadata jsonb,
    last_seen timestamp with time zone,
    last_id bigint
);


--
-- Name: swh_entity_get(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_entity_get(entity_uuid uuid) RETURNS SETOF public.entity
    LANGUAGE sql STABLE
    AS $$
  with recursive entity_hierarchy as (
  select e.*
    from entity e where uuid = entity_uuid
    union
    select p.*
    from entity_hierarchy e
    join entity p on e.parent = p.uuid
  )
  select *
  from entity_hierarchy;
$$;


--
-- Name: swh_entity_history_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_entity_history_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into entity_history (
        uuid, parent, name, type, description, homepage, active, generated, lister_metadata, metadata, validity
    ) select * from tmp_entity_history;
    return;
end
$$;


--
-- Name: swh_find_directory_entry_by_path(public.sha1_git, bytea[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_find_directory_entry_by_path(walked_dir_id public.sha1_git, dir_or_content_path bytea[]) RETURNS public.directory_entry
    LANGUAGE plpgsql
    AS $$
declare
    end_index integer;
    paths bytea default '';
    path bytea;
    res bytea[];
    r record;
begin
    end_index := array_upper(dir_or_content_path, 1);
    res[1] := walked_dir_id;

    for i in 1..end_index
    loop
        path := dir_or_content_path[i];
        -- concatenate path for patching the name in the result record (if we found it)
        if i = 1 then
            paths = path;
        else
            paths := paths || '/' || path;  -- concatenate paths
        end if;

        if i <> end_index then
            select *
            from swh_directory_walk_one(res[i] :: sha1_git)
            where name=path
            and type = 'dir'
            limit 1 into r;
        else
            select *
            from swh_directory_walk_one(res[i] :: sha1_git)
            where name=path
            limit 1 into r;
        end if;

        -- find the path
        if r is null then
           return null;
        else
            -- store the next dir to lookup the next local path from
            res[i+1] := r.target;
        end if;
    end loop;

    -- at this moment, r is the result. Patch its 'name' with the full path before returning it.
    r.name := paths;
    return r;
end
$$;


--
-- Name: swh_mktemp(regclass); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp(tblname regclass) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
    execute format('
	create temporary table tmp_%1$I
	    (like %1$I including defaults)
	    on commit drop;
      alter table tmp_%1$I drop column if exists object_id;
	', tblname);
    return;
end
$_$;


--
-- Name: swh_mktemp_dir_entry(regclass); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_dir_entry(tblname regclass) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
    execute format('
	create temporary table tmp_%1$I
	    (like %1$I including defaults, dir_id sha1_git)
	    on commit drop;
        alter table tmp_%1$I drop column id;
	', tblname);
    return;
end
$_$;


--
-- Name: swh_mktemp_entity_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_entity_history() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_entity_history (
        like entity_history including defaults) on commit drop;
    alter table tmp_entity_history drop column id;
$$;


--
-- Name: swh_mktemp_entity_lister(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_entity_lister() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_entity_lister (
    id              bigint,
    lister_metadata jsonb
  ) on commit drop;
$$;


--
-- Name: swh_mktemp_occurrence_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_occurrence_history() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_occurrence_history(
        like occurrence_history including defaults,
        visit bigint not null
    ) on commit drop;
    alter table tmp_occurrence_history
      drop column visits,
      drop column object_id;
$$;


--
-- Name: swh_mktemp_release(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_release() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_release (
        like release including defaults,
        author_fullname bytea,
        author_name bytea,
        author_email bytea
    ) on commit drop;
    alter table tmp_release drop column author;
    alter table tmp_release drop column object_id;
$$;


--
-- Name: swh_mktemp_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_revision() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_revision (
        like revision including defaults,
        author_fullname bytea,
        author_name bytea,
        author_email bytea,
        committer_fullname bytea,
        committer_name bytea,
        committer_email bytea
    ) on commit drop;
    alter table tmp_revision drop column author;
    alter table tmp_revision drop column committer;
    alter table tmp_revision drop column object_id;
$$;


--
-- Name: swh_mktemp_snapshot_branch(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_snapshot_branch() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_snapshot_branch (
      name bytea not null,
      target bytea,
      target_type snapshot_target
  ) on commit drop;
$$;


--
-- Name: swh_mktemp_tool(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_tool() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_tool (
      like tool including defaults
    ) on commit drop;
    alter table tmp_tool drop column id;
$$;


--
-- Name: occurrence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.occurrence (
    origin bigint NOT NULL,
    branch bytea NOT NULL,
    target public.sha1_git NOT NULL,
    target_type public.object_type NOT NULL
);


--
-- Name: swh_occurrence_by_origin_visit(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_occurrence_by_origin_visit(origin_id bigint, visit_id bigint) RETURNS SETOF public.occurrence
    LANGUAGE sql STABLE
    AS $$
  select origin, branch, target, target_type from occurrence_history
  where origin = origin_id and visit_id = ANY(visits);
$$;


--
-- Name: occurrence_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.occurrence_history (
    origin bigint NOT NULL,
    branch bytea NOT NULL,
    target public.sha1_git NOT NULL,
    target_type public.object_type NOT NULL,
    visits bigint[] NOT NULL,
    object_id bigint NOT NULL,
    snapshot_branch_id bigint
);


--
-- Name: swh_occurrence_get_by(bigint, bytea, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_occurrence_get_by(origin_id bigint, branch_name bytea DEFAULT NULL::bytea, date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS SETOF public.occurrence_history
    LANGUAGE plpgsql
    AS $$
declare
    filters text[] := array[] :: text[];  -- AND-clauses used to filter content
    visit_id bigint;
    q text;
begin
    if origin_id is null then
        raise exception 'Needs an origin_id to get an occurrence.';
    end if;
    filters := filters || format('origin = %L', origin_id);
    if branch_name is not null then
        filters := filters || format('branch = %L', branch_name);
    end if;
    if date is not null then
        select visit from swh_visit_find_by_date(origin_id, date) into visit_id;
    else
        select visit from origin_visit where origin = origin_id order by origin_visit.date desc limit 1 into visit_id;
    end if;
    if visit_id is null then
        return;
    end if;
    filters := filters || format('%L = any(visits)', visit_id);

    q = format('select * from occurrence_history where %s',
               array_to_string(filters, ' and '));
    return query execute q;
end
$$;


--
-- Name: swh_occurrence_history_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_occurrence_history_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  origin_id origin.id%type;
begin
  -- Create or update occurrence_history
  with occurrence_history_id_visit as (
    select tmp_occurrence_history.*, object_id, visits from tmp_occurrence_history
    left join occurrence_history using(origin, branch, target, target_type)
  ),
  occurrences_to_update as (
    select object_id, visit from occurrence_history_id_visit where object_id is not null
  ),
  update_occurrences as (
    update occurrence_history
    set visits = array(select unnest(occurrence_history.visits) as e
                        union
                       select occurrences_to_update.visit as e
                       order by e)
    from occurrences_to_update
    where occurrence_history.object_id = occurrences_to_update.object_id
  )
  insert into occurrence_history (origin, branch, target, target_type, visits)
    select origin, branch, target, target_type, ARRAY[visit]
      from occurrence_history_id_visit
      where object_id is null;

  -- update occurrence
  for origin_id in
    select distinct origin from tmp_occurrence_history
  loop
    perform swh_occurrence_update_for_origin(origin_id);
  end loop;
  return;
end
$$;


--
-- Name: swh_occurrence_update_all(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_occurrence_update_all() RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  origin_id origin.id%type;
begin
  for origin_id in
    select distinct id from origin
  loop
    perform swh_occurrence_update_for_origin(origin_id);
  end loop;
  return;
end;
$$;


--
-- Name: swh_occurrence_update_for_origin(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_occurrence_update_for_origin(origin_id bigint) RETURNS void
    LANGUAGE sql
    AS $$
  delete from occurrence where origin = origin_id;
  insert into occurrence (origin, branch, target, target_type)
    select origin, branch, target, target_type
    from occurrence_history
    where origin = origin_id and
          (select visit from origin_visit
           where origin = origin_id
           order by date desc
           limit 1) = any(visits);
$$;


--
-- Name: swh_origin_metadata_get_by_origin(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_origin_metadata_get_by_origin(origin integer) RETURNS SETOF public.origin_metadata_signature
    LANGUAGE sql STABLE
    AS $$
    select om.id as id, origin_id, discovery_date, tool_id, om.metadata,
           mp.id as provider_id, provider_name, provider_type, provider_url
    from origin_metadata as om
    inner join metadata_provider mp on om.provider_id = mp.id
    where om.origin_id = origin
    order by discovery_date desc;
$$;


--
-- Name: swh_origin_metadata_get_by_provider_type(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_origin_metadata_get_by_provider_type(origin integer, type text) RETURNS SETOF public.origin_metadata_signature
    LANGUAGE sql STABLE
    AS $$
    select om.id as id, origin_id, discovery_date, tool_id, om.metadata,
           mp.id as provider_id, provider_name, provider_type, provider_url
    from origin_metadata as om
    inner join metadata_provider mp on om.provider_id = mp.id
    where om.origin_id = origin
    and mp.provider_type = type
    order by discovery_date desc;
$$;


--
-- Name: swh_origin_visit_add(bigint, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_origin_visit_add(origin_id bigint, date timestamp with time zone) RETURNS bigint
    LANGUAGE sql
    AS $$
  with last_known_visit as (
    select coalesce(max(visit), 0) as visit
    from origin_visit
    where origin = origin_id
  )
  insert into origin_visit (origin, date, visit, status)
  values (origin_id, date, (select visit from last_known_visit) + 1, 'ongoing')
  returning visit;
$$;


--
-- Name: swh_person_add_from_release(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_person_add_from_release() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    with t as (
        select distinct author_fullname as fullname, author_name as name, author_email as email from tmp_release
    ) insert into person (fullname, name, email)
    select fullname, name, email from t
    where not exists (
        select 1
        from person p
        where t.fullname = p.fullname
    );
    return;
end
$$;


--
-- Name: swh_person_add_from_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_person_add_from_revision() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    with t as (
        select author_fullname as fullname, author_name as name, author_email as email from tmp_revision
    union
        select committer_fullname as fullname, committer_name as name, committer_email as email from tmp_revision
    ) insert into person (fullname, name, email)
    select distinct fullname, name, email from t
    where not exists (
        select 1
        from person p
        where t.fullname = p.fullname
    );
    return;
end
$$;


--
-- Name: swh_release_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_release_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    perform swh_person_add_from_release();

    insert into release (id, target, target_type, date, date_offset, date_neg_utc_offset, name, comment, author, synthetic)
    select t.id, t.target, t.target_type, t.date, t.date_offset, t.date_neg_utc_offset, t.name, t.comment, a.id, t.synthetic
    from tmp_release t
    left join person a on a.fullname = t.author_fullname;
    return;
end
$$;


--
-- Name: swh_release_get_by(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_release_get_by(origin_id bigint) RETURNS SETOF public.release_entry
    LANGUAGE sql STABLE
    AS $$
   select r.id, r.target, r.target_type, r.date, r.date_offset, r.date_neg_utc_offset,
        r.name, r.comment, r.synthetic, a.id as author_id, a.fullname as author_fullname,
        a.name as author_name, a.email as author_email, r.object_id
    from release r
    inner join occurrence_history occ on occ.target = r.target
    left join person a on a.id = r.author
    where occ.origin = origin_id and occ.target_type = 'revision' and r.target_type = 'revision';
$$;


--
-- Name: swh_release_list_by_object_id(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_release_list_by_object_id(min_excl bigint, max_incl bigint) RETURNS SETOF public.release_entry
    LANGUAGE sql STABLE
    AS $$
    with rels as (
        select * from release
        where object_id > min_excl and object_id <= max_incl
    )
    select r.id, r.target, r.target_type, r.date, r.date_offset, r.date_neg_utc_offset, r.name, r.comment,
           r.synthetic, p.id as author_id, p.fullname as author_fullname, p.name as author_name, p.email as author_email, r.object_id
    from rels r
    left join person p on p.id = r.author
    order by r.object_id;
$$;


--
-- Name: swh_revision_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    perform swh_person_add_from_revision();

    insert into revision (id, date, date_offset, date_neg_utc_offset, committer_date, committer_date_offset, committer_date_neg_utc_offset, type, directory, message, author, committer, metadata, synthetic)
    select t.id, t.date, t.date_offset, t.date_neg_utc_offset, t.committer_date, t.committer_date_offset, t.committer_date_neg_utc_offset, t.type, t.directory, t.message, a.id, c.id, t.metadata, t.synthetic
    from tmp_revision t
    left join person a on a.fullname = t.author_fullname
    left join person c on c.fullname = t.committer_fullname;
    return;
end
$$;


--
-- Name: swh_revision_find_occurrence(public.sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_find_occurrence(revision_id public.sha1_git) RETURNS public.occurrence
    LANGUAGE sql STABLE
    AS $$
	select origin, branch, target, target_type
  from swh_revision_list_children(ARRAY[revision_id] :: bytea[]) as rev_list
	left join occurrence_history occ_hist
  on rev_list.id = occ_hist.target
	where occ_hist.origin is not null and
        occ_hist.target_type = 'revision'
	limit 1;
$$;


--
-- Name: swh_revision_get_by(bigint, bytea, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_get_by(origin_id bigint, branch_name bytea DEFAULT NULL::bytea, date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS SETOF public.revision_entry
    LANGUAGE sql STABLE
    AS $$
    select r.id, r.date, r.date_offset, r.date_neg_utc_offset,
        r.committer_date, r.committer_date_offset, r.committer_date_neg_utc_offset,
        r.type, r.directory, r.message,
        a.id, a.fullname, a.name, a.email, c.id, c.fullname, c.name, c.email, r.metadata, r.synthetic,
        array(select rh.parent_id::bytea
            from revision_history rh
            where rh.id = r.id
            order by rh.parent_rank
        ) as parents, r.object_id
    from swh_occurrence_get_by(origin_id, branch_name, date) as occ
    inner join revision r on occ.target = r.id
    left join person a on a.id = r.author
    left join person c on c.id = r.committer;
$$;


--
-- Name: swh_revision_list(bytea[], bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_list(root_revisions bytea[], num_revs bigint DEFAULT NULL::bigint) RETURNS TABLE(id public.sha1_git, parents bytea[])
    LANGUAGE sql STABLE
    AS $$
    with recursive full_rev_list(id) as (
        (select id from revision where id = ANY(root_revisions))
        union
        (select h.parent_id
         from revision_history as h
         join full_rev_list on h.id = full_rev_list.id)
    ),
    rev_list as (select id from full_rev_list limit num_revs)
    select rev_list.id as id,
           array(select rh.parent_id::bytea
                 from revision_history rh
                 where rh.id = rev_list.id
                 order by rh.parent_rank
                ) as parent
    from rev_list;
$$;


--
-- Name: swh_revision_list_by_object_id(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_list_by_object_id(min_excl bigint, max_incl bigint) RETURNS SETOF public.revision_entry
    LANGUAGE sql STABLE
    AS $$
    with revs as (
        select * from revision
        where object_id > min_excl and object_id <= max_incl
    )
    select r.id, r.date, r.date_offset, r.date_neg_utc_offset,
           r.committer_date, r.committer_date_offset, r.committer_date_neg_utc_offset,
           r.type, r.directory, r.message,
           a.id, a.fullname, a.name, a.email, c.id, c.fullname, c.name, c.email, r.metadata, r.synthetic,
           array(select rh.parent_id::bytea from revision_history rh where rh.id = r.id order by rh.parent_rank)
               as parents, r.object_id
    from revs r
    left join person a on a.id = r.author
    left join person c on c.id = r.committer
    order by r.object_id;
$$;


--
-- Name: swh_revision_list_children(bytea[], bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_list_children(root_revisions bytea[], num_revs bigint DEFAULT NULL::bigint) RETURNS TABLE(id public.sha1_git, parents bytea[])
    LANGUAGE sql STABLE
    AS $$
    with recursive full_rev_list(id) as (
        (select id from revision where id = ANY(root_revisions))
        union
        (select h.id
         from revision_history as h
         join full_rev_list on h.parent_id = full_rev_list.id)
    ),
    rev_list as (select id from full_rev_list limit num_revs)
    select rev_list.id as id,
           array(select rh.parent_id::bytea
                 from revision_history rh
                 where rh.id = rev_list.id
                 order by rh.parent_rank
                ) as parent
    from rev_list;
$$;


--
-- Name: swh_revision_log(bytea[], bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_log(root_revisions bytea[], num_revs bigint DEFAULT NULL::bigint) RETURNS SETOF public.revision_entry
    LANGUAGE sql STABLE
    AS $$
    select t.id, r.date, r.date_offset, r.date_neg_utc_offset,
           r.committer_date, r.committer_date_offset, r.committer_date_neg_utc_offset,
           r.type, r.directory, r.message,
           a.id, a.fullname, a.name, a.email,
           c.id, c.fullname, c.name, c.email,
           r.metadata, r.synthetic, t.parents, r.object_id
    from swh_revision_list(root_revisions, num_revs) as t
    left join revision r on t.id = r.id
    left join person a on a.id = r.author
    left join person c on c.id = r.committer;
$$;


--
-- Name: swh_revision_walk(public.sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_revision_walk(revision_id public.sha1_git) RETURNS SETOF public.directory_entry
    LANGUAGE sql STABLE
    AS $$
  select dir_id, type, target, name, perms, status, sha1, sha1_git, sha256, length
  from swh_directory_walk((select directory from revision where id=revision_id))
$$;


--
-- Name: FUNCTION swh_revision_walk(revision_id public.sha1_git); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.swh_revision_walk(revision_id public.sha1_git) IS 'Recursively list the revision targeted directory arborescence';


--
-- Name: swh_skipped_content_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_skipped_content_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into skipped_content (sha1, sha1_git, sha256, blake2s256, length, status, reason, origin)
        select distinct sha1, sha1_git, sha256, blake2s256, length, status, reason, origin
	from tmp_skipped_content
	where (coalesce(sha1, ''), coalesce(sha1_git, ''), coalesce(sha256, '')) in (
            select coalesce(sha1, ''), coalesce(sha1_git, ''), coalesce(sha256, '')
            from swh_skipped_content_missing()
        );
        -- TODO XXX use postgres 9.5 "UPSERT" support here, when available.
        -- Specifically, using "INSERT .. ON CONFLICT IGNORE" we can avoid
        -- the extra swh_content_missing() query here.
    return;
end
$$;


--
-- Name: swh_skipped_content_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_skipped_content_missing() RETURNS SETOF public.content_signature
    LANGUAGE plpgsql
    AS $$
begin
    return query
	select sha1, sha1_git, sha256, blake2s256 from tmp_skipped_content t
	where not exists
	(select 1 from skipped_content s where
	    s.sha1 is not distinct from t.sha1 and
	    s.sha1_git is not distinct from t.sha1_git and
	    s.sha256 is not distinct from t.sha256);
    return;
end
$$;


--
-- Name: swh_snapshot_add(bigint, bigint, public.sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_snapshot_add(origin bigint, visit bigint, snapshot_id public.sha1_git) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  snapshot_object_id snapshot.object_id%type;
begin
  select object_id from snapshot where id = snapshot_id into snapshot_object_id;
  if snapshot_object_id is null then
     insert into snapshot (id) values (snapshot_id) returning object_id into snapshot_object_id;
     insert into snapshot_branch (name, target_type, target)
       select name, target_type, target from tmp_snapshot_branch tmp
       where not exists (
         select 1
         from snapshot_branch sb
         where sb.name = tmp.name
           and sb.target = tmp.target
           and sb.target_type = tmp.target_type
       )
       on conflict do nothing;
     insert into snapshot_branches (snapshot_id, branch_id)
     select snapshot_object_id, sb.object_id as branch_id
       from tmp_snapshot_branch tmp
       join snapshot_branch sb
       using (name, target, target_type)
       where tmp.target is not null and tmp.target_type is not null
     union
     select snapshot_object_id, sb.object_id as branch_id
       from tmp_snapshot_branch tmp
       join snapshot_branch sb
       using (name)
       where tmp.target is null and tmp.target_type is null
         and sb.target is null and sb.target_type is null;
  end if;
  update origin_visit ov
    set snapshot_id = snapshot_object_id
    where ov.origin=swh_snapshot_add.origin and ov.visit=swh_snapshot_add.visit;
end;
$$;


--
-- Name: swh_snapshot_get_by_id(public.sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_snapshot_get_by_id(id public.sha1_git) RETURNS SETOF public.snapshot_result
    LANGUAGE sql STABLE
    AS $$
  select
    swh_snapshot_get_by_id.id as snapshot_id, name, target, target_type
  from snapshot_branches
  inner join snapshot_branch on snapshot_branches.branch_id = snapshot_branch.object_id
  where snapshot_id = (select object_id from snapshot where snapshot.id = swh_snapshot_get_by_id.id)
$$;


--
-- Name: swh_snapshot_get_by_origin_visit(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_snapshot_get_by_origin_visit(origin_id bigint, visit_id bigint) RETURNS public.sha1_git
    LANGUAGE sql STABLE
    AS $$
  select snapshot.id
  from origin_visit
  left join snapshot
  on snapshot.object_id = origin_visit.snapshot_id
  where origin_visit.origin=origin_id and origin_visit.visit=visit_id;
$$;


--
-- Name: swh_stat_counters(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_stat_counters() RETURNS SETOF public.counter
    LANGUAGE sql STABLE
    AS $$
    select object_type as label, value as value
    from object_counts
    where object_type in (
        'content',
        'directory',
        'directory_entry_dir',
        'directory_entry_file',
        'directory_entry_rev',
        'occurrence',
        'occurrence_history',
        'origin',
        'origin_visit',
        'person',
        'entity',
        'entity_history',
        'release',
        'revision',
        'revision_history',
        'skipped_content'
    );
$$;


--
-- Name: tool; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tool (
    id integer NOT NULL,
    name text NOT NULL,
    version text NOT NULL,
    configuration jsonb
);


--
-- Name: TABLE tool; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tool IS 'Tool information';


--
-- Name: COLUMN tool.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tool.id IS 'Tool identifier';


--
-- Name: COLUMN tool.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tool.version IS 'Tool version';


--
-- Name: COLUMN tool.configuration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tool.configuration IS 'Tool configuration: command line, flags, etc...';


--
-- Name: swh_tool_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_tool_add() RETURNS SETOF public.tool
    LANGUAGE plpgsql
    AS $$
begin
      insert into tool(name, version, configuration)
      select name, version, configuration from tmp_tool tmp
      on conflict(name, version, configuration) do nothing;

      return query
          select id, name, version, configuration
          from tmp_tool join tool
              using(name, version, configuration);

      return;
end
$$;


--
-- Name: swh_update_counter(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_update_counter(object_type text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
    execute format('
	insert into object_counts
    (value, last_update, object_type)
  values
    ((select count(*) from %1$I), NOW(), %1$L)
  on conflict (object_type) do update set
    value = excluded.value,
    last_update = excluded.last_update',
  object_type);
    return;
end;
$_$;


--
-- Name: swh_update_counter_bucketed(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_update_counter_bucketed() RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  query text;
  line_to_update int;
  new_value bigint;
begin
  select
    object_counts_bucketed.line,
    format(
      'select count(%I) from %I where %s',
      coalesce(identifier, '*'),
      object_type,
      coalesce(
        concat_ws(
          ' and ',
          case when bucket_start is not null then
            format('%I >= %L', identifier, bucket_start) -- lower bound condition, inclusive
          end,
          case when bucket_end is not null then
            format('%I < %L', identifier, bucket_end) -- upper bound condition, exclusive
          end
        ),
        'true'
      )
    )
    from object_counts_bucketed
    order by coalesce(last_update, now() - '1 month'::interval) asc
    limit 1
    into line_to_update, query;

  execute query into new_value;

  update object_counts_bucketed
    set value = new_value,
        last_update = now()
    where object_counts_bucketed.line = line_to_update;

END
$$;


--
-- Name: swh_update_counters_from_buckets(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_update_counters_from_buckets() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
with to_update as (
  select object_type, sum(value) as value, max(last_update) as last_update
  from object_counts_bucketed ob1
  where not exists (
    select 1 from object_counts_bucketed ob2
    where ob1.object_type = ob2.object_type
    and value is null
    )
  group by object_type
) update object_counts
  set
    value = to_update.value,
    last_update = to_update.last_update
  from to_update
  where
    object_counts.object_type = to_update.object_type
    and object_counts.value != to_update.value;
return null;
end
$$;


--
-- Name: swh_update_entity_from_entity_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_update_entity_from_entity_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    insert into entity (uuid, parent, name, type, description, homepage, active, generated,
      lister_metadata, metadata, last_seen, last_id)
      select uuid, parent, name, type, description, homepage, active, generated,
             lister_metadata, metadata, unnest(validity), id
      from entity_history
      where uuid = NEW.uuid
      order by unnest(validity) desc limit 1
    on conflict (uuid) do update set
      parent = EXCLUDED.parent,
      name = EXCLUDED.name,
      type = EXCLUDED.type,
      description = EXCLUDED.description,
      homepage = EXCLUDED.homepage,
      active = EXCLUDED.active,
      generated = EXCLUDED.generated,
      lister_metadata = EXCLUDED.lister_metadata,
      metadata = EXCLUDED.metadata,
      last_seen = EXCLUDED.last_seen,
      last_id = EXCLUDED.last_id;

    return null;
end
$$;


--
-- Name: origin_visit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.origin_visit (
    origin bigint NOT NULL,
    visit bigint NOT NULL,
    date timestamp with time zone NOT NULL,
    status public.origin_visit_status NOT NULL,
    metadata jsonb,
    snapshot_id bigint
);


--
-- Name: COLUMN origin_visit.origin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_visit.origin IS 'Visited origin';


--
-- Name: COLUMN origin_visit.visit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_visit.visit IS 'Visit number the visit occurred for that origin';


--
-- Name: COLUMN origin_visit.date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_visit.date IS 'Visit date for that origin';


--
-- Name: COLUMN origin_visit.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_visit.status IS 'Visit status for that origin';


--
-- Name: COLUMN origin_visit.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_visit.metadata IS 'Metadata associated with the visit';


--
-- Name: COLUMN origin_visit.snapshot_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_visit.snapshot_id IS 'id of the snapshot associated with the visit';


--
-- Name: swh_visit_find_by_date(bigint, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_visit_find_by_date(origin bigint, visit_date timestamp with time zone DEFAULT now()) RETURNS public.origin_visit
    LANGUAGE sql STABLE
    AS $$
  with closest_two_visits as ((
    select ov, (date - visit_date) as interval
    from origin_visit ov
    where ov.origin = origin
          and ov.date >= visit_date
    order by ov.date asc
    limit 1
  ) union (
    select ov, (visit_date - date) as interval
    from origin_visit ov
    where ov.origin = origin
          and ov.date < visit_date
    order by ov.date desc
    limit 1
  )) select (ov).* from closest_two_visits order by interval limit 1
$$;


--
-- Name: swh_visit_get(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_visit_get(origin bigint) RETURNS public.origin_visit
    LANGUAGE sql STABLE
    AS $$
    select *
    from origin_visit
    where origin=origin
    order by date desc
$$;


--
-- Name: content_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_object_id_seq OWNED BY public.content.object_id;


--
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dbversion (
    version integer NOT NULL,
    release timestamp with time zone,
    description text
);


--
-- Name: directory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.directory (
    id public.sha1_git NOT NULL,
    dir_entries bigint[],
    file_entries bigint[],
    rev_entries bigint[],
    object_id bigint NOT NULL
);


--
-- Name: directory_entry_dir; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.directory_entry_dir (
    id bigint NOT NULL,
    target public.sha1_git,
    name public.unix_path,
    perms public.file_perms
);


--
-- Name: directory_entry_dir_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.directory_entry_dir_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_entry_dir_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.directory_entry_dir_id_seq OWNED BY public.directory_entry_dir.id;


--
-- Name: directory_entry_file; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.directory_entry_file (
    id bigint NOT NULL,
    target public.sha1_git,
    name public.unix_path,
    perms public.file_perms
);


--
-- Name: directory_entry_file_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.directory_entry_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_entry_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.directory_entry_file_id_seq OWNED BY public.directory_entry_file.id;


--
-- Name: directory_entry_rev; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.directory_entry_rev (
    id bigint NOT NULL,
    target public.sha1_git,
    name public.unix_path,
    perms public.file_perms
);


--
-- Name: directory_entry_rev_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.directory_entry_rev_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_entry_rev_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.directory_entry_rev_id_seq OWNED BY public.directory_entry_rev.id;


--
-- Name: directory_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.directory_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.directory_object_id_seq OWNED BY public.directory.object_id;


--
-- Name: entity_equivalence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_equivalence (
    entity1 uuid NOT NULL,
    entity2 uuid NOT NULL,
    CONSTRAINT order_entities CHECK ((entity1 < entity2))
);


--
-- Name: entity_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_history (
    id bigint NOT NULL,
    uuid uuid,
    parent uuid,
    name text NOT NULL,
    type public.entity_type NOT NULL,
    description text,
    homepage text,
    active boolean NOT NULL,
    generated boolean NOT NULL,
    lister_metadata jsonb,
    metadata jsonb,
    validity timestamp with time zone[]
);


--
-- Name: entity_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entity_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entity_history_id_seq OWNED BY public.entity_history.id;


--
-- Name: fetch_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fetch_history (
    id bigint NOT NULL,
    origin bigint,
    date timestamp with time zone NOT NULL,
    status boolean,
    result jsonb,
    stdout text,
    stderr text,
    duration interval
);


--
-- Name: fetch_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fetch_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fetch_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fetch_history_id_seq OWNED BY public.fetch_history.id;


--
-- Name: list_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.list_history (
    id bigint NOT NULL,
    date timestamp with time zone NOT NULL,
    status boolean,
    result jsonb,
    stdout text,
    stderr text,
    duration interval,
    entity uuid
);


--
-- Name: list_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.list_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.list_history_id_seq OWNED BY public.list_history.id;


--
-- Name: listable_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listable_entity (
    uuid uuid NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    list_engine text,
    list_url text,
    list_params jsonb,
    latest_list timestamp with time zone
);


--
-- Name: metadata_provider; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metadata_provider (
    id integer NOT NULL,
    provider_name text NOT NULL,
    provider_type text NOT NULL,
    provider_url text,
    metadata jsonb
);


--
-- Name: TABLE metadata_provider; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.metadata_provider IS 'Metadata provider information';


--
-- Name: COLUMN metadata_provider.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.metadata_provider.id IS 'Provider''s identifier';


--
-- Name: COLUMN metadata_provider.provider_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.metadata_provider.provider_name IS 'Provider''s name';


--
-- Name: COLUMN metadata_provider.provider_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.metadata_provider.provider_url IS 'Provider''s url';


--
-- Name: COLUMN metadata_provider.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.metadata_provider.metadata IS 'Other metadata about provider';


--
-- Name: metadata_provider_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.metadata_provider_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metadata_provider_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.metadata_provider_id_seq OWNED BY public.metadata_provider.id;


--
-- Name: object_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.object_counts (
    object_type text NOT NULL,
    value bigint,
    last_update timestamp with time zone,
    single_update boolean
);


--
-- Name: object_counts_bucketed; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.object_counts_bucketed (
    line integer NOT NULL,
    object_type text NOT NULL,
    identifier text NOT NULL,
    bucket_start bytea,
    bucket_end bytea,
    value bigint,
    last_update timestamp with time zone
);


--
-- Name: object_counts_bucketed_line_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.object_counts_bucketed_line_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: object_counts_bucketed_line_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.object_counts_bucketed_line_seq OWNED BY public.object_counts_bucketed.line;


--
-- Name: occurrence_history_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.occurrence_history_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: occurrence_history_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.occurrence_history_object_id_seq OWNED BY public.occurrence_history.object_id;


--
-- Name: origin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.origin (
    id bigint NOT NULL,
    type text,
    url text NOT NULL,
    lister uuid,
    project uuid
);


--
-- Name: origin_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.origin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: origin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.origin_id_seq OWNED BY public.origin.id;


--
-- Name: origin_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.origin_metadata (
    id bigint NOT NULL,
    origin_id bigint NOT NULL,
    discovery_date timestamp with time zone NOT NULL,
    provider_id bigint NOT NULL,
    tool_id bigint NOT NULL,
    metadata jsonb NOT NULL
);


--
-- Name: TABLE origin_metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.origin_metadata IS 'keeps all metadata found concerning an origin';


--
-- Name: COLUMN origin_metadata.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_metadata.id IS 'the origin_metadata object''s id';


--
-- Name: COLUMN origin_metadata.origin_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_metadata.origin_id IS 'the origin id for which the metadata was found';


--
-- Name: COLUMN origin_metadata.discovery_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_metadata.discovery_date IS 'the date of retrieval';


--
-- Name: COLUMN origin_metadata.provider_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_metadata.provider_id IS 'the metadata provider: github, openhub, deposit, etc.';


--
-- Name: COLUMN origin_metadata.tool_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_metadata.tool_id IS 'the tool used for extracting metadata: lister-github, etc.';


--
-- Name: COLUMN origin_metadata.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.origin_metadata.metadata IS 'metadata in json format but with original terms';


--
-- Name: origin_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.origin_metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: origin_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.origin_metadata_id_seq OWNED BY public.origin_metadata.id;


--
-- Name: person; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.person (
    id bigint NOT NULL,
    name bytea,
    email bytea,
    fullname bytea NOT NULL
);


--
-- Name: person_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.person_id_seq OWNED BY public.person.id;


--
-- Name: release; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.release (
    id public.sha1_git NOT NULL,
    target public.sha1_git,
    date timestamp with time zone,
    date_offset smallint,
    name bytea,
    comment bytea,
    author bigint,
    synthetic boolean DEFAULT false NOT NULL,
    object_id bigint NOT NULL,
    target_type public.object_type NOT NULL,
    date_neg_utc_offset boolean
);


--
-- Name: release_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.release_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: release_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.release_object_id_seq OWNED BY public.release.object_id;


--
-- Name: revision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.revision (
    id public.sha1_git NOT NULL,
    date timestamp with time zone,
    date_offset smallint,
    committer_date timestamp with time zone,
    committer_date_offset smallint,
    type public.revision_type NOT NULL,
    directory public.sha1_git,
    message bytea,
    author bigint,
    committer bigint,
    synthetic boolean DEFAULT false NOT NULL,
    metadata jsonb,
    object_id bigint NOT NULL,
    date_neg_utc_offset boolean,
    committer_date_neg_utc_offset boolean
);


--
-- Name: revision_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.revision_history (
    id public.sha1_git NOT NULL,
    parent_id public.sha1_git,
    parent_rank integer DEFAULT 0 NOT NULL
);


--
-- Name: revision_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.revision_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: revision_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.revision_object_id_seq OWNED BY public.revision.object_id;


--
-- Name: skipped_content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.skipped_content (
    sha1 public.sha1,
    sha1_git public.sha1_git,
    sha256 public.sha256,
    blake2s256 public.blake2s256,
    length bigint NOT NULL,
    ctime timestamp with time zone DEFAULT now() NOT NULL,
    status public.content_status DEFAULT 'absent'::public.content_status NOT NULL,
    reason text NOT NULL,
    origin bigint,
    object_id bigint NOT NULL
);


--
-- Name: skipped_content_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.skipped_content_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: skipped_content_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.skipped_content_object_id_seq OWNED BY public.skipped_content.object_id;


--
-- Name: snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snapshot (
    object_id bigint NOT NULL,
    id public.sha1_git
);


--
-- Name: snapshot_branch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snapshot_branch (
    object_id bigint NOT NULL,
    name bytea NOT NULL,
    target bytea,
    target_type public.snapshot_target,
    CONSTRAINT snapshot_branch_target_check CHECK (((target_type IS NULL) = (target IS NULL))),
    CONSTRAINT snapshot_target_check CHECK (((target_type <> ALL (ARRAY['content'::public.snapshot_target, 'directory'::public.snapshot_target, 'revision'::public.snapshot_target, 'release'::public.snapshot_target, 'snapshot'::public.snapshot_target])) OR (length(target) = 20)))
);


--
-- Name: snapshot_branch_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.snapshot_branch_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: snapshot_branch_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.snapshot_branch_object_id_seq OWNED BY public.snapshot_branch.object_id;


--
-- Name: snapshot_branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snapshot_branches (
    snapshot_id bigint NOT NULL,
    branch_id bigint NOT NULL
);


--
-- Name: snapshot_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.snapshot_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: snapshot_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.snapshot_object_id_seq OWNED BY public.snapshot.object_id;


--
-- Name: tool_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tool_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tool_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tool_id_seq OWNED BY public.tool.id;


--
-- Name: content object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content ALTER COLUMN object_id SET DEFAULT nextval('public.content_object_id_seq'::regclass);


--
-- Name: directory object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory ALTER COLUMN object_id SET DEFAULT nextval('public.directory_object_id_seq'::regclass);


--
-- Name: directory_entry_dir id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_entry_dir ALTER COLUMN id SET DEFAULT nextval('public.directory_entry_dir_id_seq'::regclass);


--
-- Name: directory_entry_file id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_entry_file ALTER COLUMN id SET DEFAULT nextval('public.directory_entry_file_id_seq'::regclass);


--
-- Name: directory_entry_rev id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_entry_rev ALTER COLUMN id SET DEFAULT nextval('public.directory_entry_rev_id_seq'::regclass);


--
-- Name: entity_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_history ALTER COLUMN id SET DEFAULT nextval('public.entity_history_id_seq'::regclass);


--
-- Name: fetch_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fetch_history ALTER COLUMN id SET DEFAULT nextval('public.fetch_history_id_seq'::regclass);


--
-- Name: list_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_history ALTER COLUMN id SET DEFAULT nextval('public.list_history_id_seq'::regclass);


--
-- Name: metadata_provider id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metadata_provider ALTER COLUMN id SET DEFAULT nextval('public.metadata_provider_id_seq'::regclass);


--
-- Name: object_counts_bucketed line; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.object_counts_bucketed ALTER COLUMN line SET DEFAULT nextval('public.object_counts_bucketed_line_seq'::regclass);


--
-- Name: occurrence_history object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occurrence_history ALTER COLUMN object_id SET DEFAULT nextval('public.occurrence_history_object_id_seq'::regclass);


--
-- Name: origin id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin ALTER COLUMN id SET DEFAULT nextval('public.origin_id_seq'::regclass);


--
-- Name: origin_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_metadata ALTER COLUMN id SET DEFAULT nextval('public.origin_metadata_id_seq'::regclass);


--
-- Name: person id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person ALTER COLUMN id SET DEFAULT nextval('public.person_id_seq'::regclass);


--
-- Name: release object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release ALTER COLUMN object_id SET DEFAULT nextval('public.release_object_id_seq'::regclass);


--
-- Name: revision object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revision ALTER COLUMN object_id SET DEFAULT nextval('public.revision_object_id_seq'::regclass);


--
-- Name: skipped_content object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skipped_content ALTER COLUMN object_id SET DEFAULT nextval('public.skipped_content_object_id_seq'::regclass);


--
-- Name: snapshot object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snapshot ALTER COLUMN object_id SET DEFAULT nextval('public.snapshot_object_id_seq'::regclass);


--
-- Name: snapshot_branch object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snapshot_branch ALTER COLUMN object_id SET DEFAULT nextval('public.snapshot_branch_object_id_seq'::regclass);


--
-- Name: tool id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool ALTER COLUMN id SET DEFAULT nextval('public.tool_id_seq'::regclass);


--
-- Data for Name: content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.content (sha1, sha1_git, sha256, blake2s256, length, ctime, status, object_id) FROM stdin;
\.


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.dbversion (version, release, description) FROM stdin;
119	2018-06-05 13:57:26.649524+02	Work In Progress
\.


--
-- Data for Name: directory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.directory (id, dir_entries, file_entries, rev_entries, object_id) FROM stdin;
\.


--
-- Data for Name: directory_entry_dir; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.directory_entry_dir (id, target, name, perms) FROM stdin;
\.


--
-- Data for Name: directory_entry_file; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.directory_entry_file (id, target, name, perms) FROM stdin;
\.


--
-- Data for Name: directory_entry_rev; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.directory_entry_rev (id, target, name, perms) FROM stdin;
\.


--
-- Data for Name: entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.entity (uuid, parent, name, type, description, homepage, active, generated, lister_metadata, metadata, last_seen, last_id) FROM stdin;
5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	1
6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	2
7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	2018-06-05 13:57:26.95401+02	3
4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	4
5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	5
4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	6
aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	7
34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	8
e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	9
9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	10
ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	2018-06-05 13:57:26.95401+02	11
\.


--
-- Data for Name: entity_equivalence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.entity_equivalence (entity1, entity2) FROM stdin;
\.


--
-- Data for Name: entity_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.entity_history (id, uuid, parent, name, type, description, homepage, active, generated, lister_metadata, metadata, validity) FROM stdin;
1	5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
2	6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
3	7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
4	4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
5	5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
6	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
8	34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
9	e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
10	9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
11	ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	{"2018-06-05 13:57:26.95401+02"}
\.


--
-- Data for Name: fetch_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fetch_history (id, origin, date, status, result, stdout, stderr, duration) FROM stdin;
\.


--
-- Data for Name: list_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.list_history (id, date, status, result, stdout, stderr, duration, entity) FROM stdin;
\.


--
-- Data for Name: listable_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.listable_entity (uuid, enabled, list_engine, list_url, list_params, latest_list) FROM stdin;
34bd6b1b-463f-43e5-a697-785107f598e4	t	swh.lister.github	\N	\N	\N
\.


--
-- Data for Name: metadata_provider; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.metadata_provider (id, provider_name, provider_type, provider_url, metadata) FROM stdin;
\.


--
-- Data for Name: object_counts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.object_counts (object_type, value, last_update, single_update) FROM stdin;
\.


--
-- Data for Name: object_counts_bucketed; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.object_counts_bucketed (line, object_type, identifier, bucket_start, bucket_end, value, last_update) FROM stdin;
\.


--
-- Data for Name: occurrence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.occurrence (origin, branch, target, target_type) FROM stdin;
\.


--
-- Data for Name: occurrence_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.occurrence_history (origin, branch, target, target_type, visits, object_id, snapshot_branch_id) FROM stdin;
\.


--
-- Data for Name: origin; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.origin (id, type, url, lister, project) FROM stdin;
\.


--
-- Data for Name: origin_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.origin_metadata (id, origin_id, discovery_date, provider_id, tool_id, metadata) FROM stdin;
\.


--
-- Data for Name: origin_visit; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.origin_visit (origin, visit, date, status, metadata, snapshot_id) FROM stdin;
\.


--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.person (id, name, email, fullname) FROM stdin;
\.


--
-- Data for Name: release; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.release (id, target, date, date_offset, name, comment, author, synthetic, object_id, target_type, date_neg_utc_offset) FROM stdin;
\.


--
-- Data for Name: revision; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.revision (id, date, date_offset, committer_date, committer_date_offset, type, directory, message, author, committer, synthetic, metadata, object_id, date_neg_utc_offset, committer_date_neg_utc_offset) FROM stdin;
\.


--
-- Data for Name: revision_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.revision_history (id, parent_id, parent_rank) FROM stdin;
\.


--
-- Data for Name: skipped_content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.skipped_content (sha1, sha1_git, sha256, blake2s256, length, ctime, status, reason, origin, object_id) FROM stdin;
\.


--
-- Data for Name: snapshot; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snapshot (object_id, id) FROM stdin;
\.


--
-- Data for Name: snapshot_branch; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snapshot_branch (object_id, name, target, target_type) FROM stdin;
\.


--
-- Data for Name: snapshot_branches; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snapshot_branches (snapshot_id, branch_id) FROM stdin;
\.


--
-- Data for Name: tool; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tool (id, name, version, configuration) FROM stdin;
\.


--
-- Name: content_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.content_object_id_seq', 1, false);


--
-- Name: directory_entry_dir_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.directory_entry_dir_id_seq', 1, false);


--
-- Name: directory_entry_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.directory_entry_file_id_seq', 1, false);


--
-- Name: directory_entry_rev_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.directory_entry_rev_id_seq', 1, false);


--
-- Name: directory_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.directory_object_id_seq', 1, false);


--
-- Name: entity_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.entity_history_id_seq', 11, true);


--
-- Name: fetch_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fetch_history_id_seq', 1, false);


--
-- Name: list_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.list_history_id_seq', 1, false);


--
-- Name: metadata_provider_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.metadata_provider_id_seq', 1, false);


--
-- Name: object_counts_bucketed_line_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.object_counts_bucketed_line_seq', 1, false);


--
-- Name: occurrence_history_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.occurrence_history_object_id_seq', 1, false);


--
-- Name: origin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.origin_id_seq', 1, false);


--
-- Name: origin_metadata_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.origin_metadata_id_seq', 1, false);


--
-- Name: person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.person_id_seq', 1, false);


--
-- Name: release_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.release_object_id_seq', 1, false);


--
-- Name: revision_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.revision_object_id_seq', 1, false);


--
-- Name: skipped_content_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.skipped_content_object_id_seq', 1, false);


--
-- Name: snapshot_branch_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.snapshot_branch_object_id_seq', 1, false);


--
-- Name: snapshot_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.snapshot_object_id_seq', 1, false);


--
-- Name: tool_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tool_id_seq', 1, false);


--
-- Name: content content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content
    ADD CONSTRAINT content_pkey PRIMARY KEY (sha1);


--
-- Name: dbversion dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: directory_entry_dir directory_entry_dir_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_entry_dir
    ADD CONSTRAINT directory_entry_dir_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_file directory_entry_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_entry_file
    ADD CONSTRAINT directory_entry_file_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_rev directory_entry_rev_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_entry_rev
    ADD CONSTRAINT directory_entry_rev_pkey PRIMARY KEY (id);


--
-- Name: directory directory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory
    ADD CONSTRAINT directory_pkey PRIMARY KEY (id);


--
-- Name: entity_equivalence entity_equivalence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_equivalence
    ADD CONSTRAINT entity_equivalence_pkey PRIMARY KEY (entity1, entity2);


--
-- Name: entity_history entity_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_history
    ADD CONSTRAINT entity_history_pkey PRIMARY KEY (id);


--
-- Name: entity entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (uuid);


--
-- Name: fetch_history fetch_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fetch_history
    ADD CONSTRAINT fetch_history_pkey PRIMARY KEY (id);


--
-- Name: list_history list_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_history
    ADD CONSTRAINT list_history_pkey PRIMARY KEY (id);


--
-- Name: listable_entity listable_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listable_entity
    ADD CONSTRAINT listable_entity_pkey PRIMARY KEY (uuid);


--
-- Name: metadata_provider metadata_provider_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metadata_provider
    ADD CONSTRAINT metadata_provider_pkey PRIMARY KEY (id);


--
-- Name: object_counts_bucketed object_counts_bucketed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.object_counts_bucketed
    ADD CONSTRAINT object_counts_bucketed_pkey PRIMARY KEY (line);


--
-- Name: object_counts object_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.object_counts
    ADD CONSTRAINT object_counts_pkey PRIMARY KEY (object_type);


--
-- Name: occurrence_history occurrence_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occurrence_history
    ADD CONSTRAINT occurrence_history_pkey PRIMARY KEY (object_id);


--
-- Name: occurrence occurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occurrence
    ADD CONSTRAINT occurrence_pkey PRIMARY KEY (origin, branch);


--
-- Name: origin_metadata origin_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_metadata
    ADD CONSTRAINT origin_metadata_pkey PRIMARY KEY (id);


--
-- Name: origin origin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin
    ADD CONSTRAINT origin_pkey PRIMARY KEY (id);


--
-- Name: origin_visit origin_visit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_visit
    ADD CONSTRAINT origin_visit_pkey PRIMARY KEY (origin, visit);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: release release_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release
    ADD CONSTRAINT release_pkey PRIMARY KEY (id);


--
-- Name: revision_history revision_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revision_history
    ADD CONSTRAINT revision_history_pkey PRIMARY KEY (id, parent_rank);


--
-- Name: revision revision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revision
    ADD CONSTRAINT revision_pkey PRIMARY KEY (id);


--
-- Name: skipped_content skipped_content_sha1_sha1_git_sha256_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skipped_content
    ADD CONSTRAINT skipped_content_sha1_sha1_git_sha256_key UNIQUE (sha1, sha1_git, sha256);


--
-- Name: snapshot_branch snapshot_branch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snapshot_branch
    ADD CONSTRAINT snapshot_branch_pkey PRIMARY KEY (object_id);


--
-- Name: snapshot_branches snapshot_branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snapshot_branches
    ADD CONSTRAINT snapshot_branches_pkey PRIMARY KEY (snapshot_id, branch_id);


--
-- Name: snapshot snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snapshot
    ADD CONSTRAINT snapshot_pkey PRIMARY KEY (object_id);


--
-- Name: tool tool_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool
    ADD CONSTRAINT tool_pkey PRIMARY KEY (id);


--
-- Name: content_blake2s256_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_blake2s256_idx ON public.content USING btree (blake2s256);


--
-- Name: content_ctime_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_ctime_idx ON public.content USING btree (ctime);


--
-- Name: content_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX content_object_id_idx ON public.content USING btree (object_id);


--
-- Name: content_sha1_git_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX content_sha1_git_idx ON public.content USING btree (sha1_git);


--
-- Name: content_sha256_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_sha256_idx ON public.content USING btree (sha256);


--
-- Name: directory_dir_entries_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_dir_entries_idx ON public.directory USING gin (dir_entries);


--
-- Name: directory_entry_dir_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX directory_entry_dir_target_name_perms_idx ON public.directory_entry_dir USING btree (target, name, perms);


--
-- Name: directory_entry_file_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX directory_entry_file_target_name_perms_idx ON public.directory_entry_file USING btree (target, name, perms);


--
-- Name: directory_entry_rev_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX directory_entry_rev_target_name_perms_idx ON public.directory_entry_rev USING btree (target, name, perms);


--
-- Name: directory_file_entries_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_file_entries_idx ON public.directory USING gin (file_entries);


--
-- Name: directory_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX directory_object_id_idx ON public.directory USING btree (object_id);


--
-- Name: directory_rev_entries_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_rev_entries_idx ON public.directory USING gin (rev_entries);


--
-- Name: entity_history_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_history_name_idx ON public.entity_history USING btree (name);


--
-- Name: entity_history_uuid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_history_uuid_idx ON public.entity_history USING btree (uuid);


--
-- Name: entity_lister_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_lister_metadata_idx ON public.entity USING gin (lister_metadata jsonb_path_ops);


--
-- Name: entity_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_name_idx ON public.entity USING btree (name);


--
-- Name: metadata_provider_provider_name_provider_url_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX metadata_provider_provider_name_provider_url_idx ON public.metadata_provider USING btree (provider_name, provider_url);


--
-- Name: occurrence_history_origin_branch_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX occurrence_history_origin_branch_idx ON public.occurrence_history USING btree (origin, branch);


--
-- Name: occurrence_history_origin_branch_target_target_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX occurrence_history_origin_branch_target_target_type_idx ON public.occurrence_history USING btree (origin, branch, target, target_type);


--
-- Name: occurrence_history_target_target_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX occurrence_history_target_target_type_idx ON public.occurrence_history USING btree (target, target_type);


--
-- Name: origin_metadata_origin_id_provider_id_tool_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_metadata_origin_id_provider_id_tool_id_idx ON public.origin_metadata USING btree (origin_id, provider_id, tool_id);


--
-- Name: origin_type_url_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_type_url_idx ON public.origin USING btree (type, url);


--
-- Name: origin_visit_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_visit_date_idx ON public.origin_visit USING btree (date);


--
-- Name: person_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_email_idx ON public.person USING btree (email);


--
-- Name: person_fullname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX person_fullname_idx ON public.person USING btree (fullname);


--
-- Name: person_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_name_idx ON public.person USING btree (name);


--
-- Name: release_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX release_object_id_idx ON public.release USING btree (object_id);


--
-- Name: release_target_target_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX release_target_target_type_idx ON public.release USING btree (target, target_type);


--
-- Name: revision_directory_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revision_directory_idx ON public.revision USING btree (directory);


--
-- Name: revision_history_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revision_history_parent_id_idx ON public.revision_history USING btree (parent_id);


--
-- Name: revision_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX revision_object_id_idx ON public.revision USING btree (object_id);


--
-- Name: skipped_content_blake2s256_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX skipped_content_blake2s256_idx ON public.skipped_content USING btree (blake2s256);


--
-- Name: skipped_content_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX skipped_content_object_id_idx ON public.skipped_content USING btree (object_id);


--
-- Name: skipped_content_sha1_git_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX skipped_content_sha1_git_idx ON public.skipped_content USING btree (sha1_git);


--
-- Name: skipped_content_sha1_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX skipped_content_sha1_idx ON public.skipped_content USING btree (sha1);


--
-- Name: skipped_content_sha256_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX skipped_content_sha256_idx ON public.skipped_content USING btree (sha256);


--
-- Name: snapshot_branch_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX snapshot_branch_name_idx ON public.snapshot_branch USING btree (name) WHERE ((target_type IS NULL) AND (target IS NULL));


--
-- Name: snapshot_branch_target_type_target_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX snapshot_branch_target_type_target_name_idx ON public.snapshot_branch USING btree (target_type, target, name);


--
-- Name: snapshot_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX snapshot_id_idx ON public.snapshot USING btree (id);


--
-- Name: tool_name_version_configuration_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tool_name_version_configuration_idx ON public.tool USING btree (name, version, configuration);


--
-- Name: content notify_new_content; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_content AFTER INSERT ON public.content FOR EACH ROW EXECUTE PROCEDURE public.notify_new_content();


--
-- Name: directory notify_new_directory; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_directory AFTER INSERT ON public.directory FOR EACH ROW EXECUTE PROCEDURE public.notify_new_directory();


--
-- Name: origin notify_new_origin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_origin AFTER INSERT ON public.origin FOR EACH ROW EXECUTE PROCEDURE public.notify_new_origin();


--
-- Name: origin_visit notify_new_origin_visit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_origin_visit AFTER INSERT ON public.origin_visit FOR EACH ROW EXECUTE PROCEDURE public.notify_new_origin_visit();


--
-- Name: release notify_new_release; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_release AFTER INSERT ON public.release FOR EACH ROW EXECUTE PROCEDURE public.notify_new_release();


--
-- Name: revision notify_new_revision; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_revision AFTER INSERT ON public.revision FOR EACH ROW EXECUTE PROCEDURE public.notify_new_revision();


--
-- Name: skipped_content notify_new_skipped_content; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_skipped_content AFTER INSERT ON public.skipped_content FOR EACH ROW EXECUTE PROCEDURE public.notify_new_skipped_content();


--
-- Name: object_counts_bucketed update_counts_from_bucketed; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_counts_from_bucketed AFTER INSERT OR UPDATE ON public.object_counts_bucketed FOR EACH ROW WHEN (((new.line % 256) = 0)) EXECUTE PROCEDURE public.swh_update_counters_from_buckets();


--
-- Name: entity_history update_entity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_entity AFTER INSERT OR UPDATE ON public.entity_history FOR EACH ROW EXECUTE PROCEDURE public.swh_update_entity_from_entity_history();


--
-- Name: entity_equivalence entity_equivalence_entity1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_equivalence
    ADD CONSTRAINT entity_equivalence_entity1_fkey FOREIGN KEY (entity1) REFERENCES public.entity(uuid);


--
-- Name: entity_equivalence entity_equivalence_entity2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_equivalence
    ADD CONSTRAINT entity_equivalence_entity2_fkey FOREIGN KEY (entity2) REFERENCES public.entity(uuid);


--
-- Name: entity entity_last_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_last_id_fkey FOREIGN KEY (last_id) REFERENCES public.entity_history(id);


--
-- Name: entity entity_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_parent_fkey FOREIGN KEY (parent) REFERENCES public.entity(uuid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: fetch_history fetch_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fetch_history
    ADD CONSTRAINT fetch_history_origin_fkey FOREIGN KEY (origin) REFERENCES public.origin(id);


--
-- Name: list_history list_history_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_history
    ADD CONSTRAINT list_history_entity_fkey FOREIGN KEY (entity) REFERENCES public.listable_entity(uuid);


--
-- Name: listable_entity listable_entity_uuid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listable_entity
    ADD CONSTRAINT listable_entity_uuid_fkey FOREIGN KEY (uuid) REFERENCES public.entity(uuid);


--
-- Name: occurrence_history occurrence_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occurrence_history
    ADD CONSTRAINT occurrence_history_origin_fkey FOREIGN KEY (origin) REFERENCES public.origin(id);


--
-- Name: occurrence occurrence_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occurrence
    ADD CONSTRAINT occurrence_origin_fkey FOREIGN KEY (origin) REFERENCES public.origin(id);


--
-- Name: origin origin_lister_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin
    ADD CONSTRAINT origin_lister_fkey FOREIGN KEY (lister) REFERENCES public.listable_entity(uuid);


--
-- Name: origin_metadata origin_metadata_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_metadata
    ADD CONSTRAINT origin_metadata_origin_fkey FOREIGN KEY (origin_id) REFERENCES public.origin(id);


--
-- Name: origin_metadata origin_metadata_provider_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_metadata
    ADD CONSTRAINT origin_metadata_provider_fkey FOREIGN KEY (provider_id) REFERENCES public.metadata_provider(id);


--
-- Name: origin_metadata origin_metadata_tool_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_metadata
    ADD CONSTRAINT origin_metadata_tool_fkey FOREIGN KEY (tool_id) REFERENCES public.tool(id);


--
-- Name: origin origin_project_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin
    ADD CONSTRAINT origin_project_fkey FOREIGN KEY (project) REFERENCES public.entity(uuid);


--
-- Name: origin_visit origin_visit_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_visit
    ADD CONSTRAINT origin_visit_origin_fkey FOREIGN KEY (origin) REFERENCES public.origin(id);


--
-- Name: origin_visit origin_visit_snapshot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_visit
    ADD CONSTRAINT origin_visit_snapshot_id_fkey FOREIGN KEY (snapshot_id) REFERENCES public.snapshot(object_id);


--
-- Name: release release_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release
    ADD CONSTRAINT release_author_fkey FOREIGN KEY (author) REFERENCES public.person(id);


--
-- Name: revision revision_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revision
    ADD CONSTRAINT revision_author_fkey FOREIGN KEY (author) REFERENCES public.person(id);


--
-- Name: revision revision_committer_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revision
    ADD CONSTRAINT revision_committer_fkey FOREIGN KEY (committer) REFERENCES public.person(id);


--
-- Name: revision_history revision_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revision_history
    ADD CONSTRAINT revision_history_id_fkey FOREIGN KEY (id) REFERENCES public.revision(id);


--
-- Name: skipped_content skipped_content_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skipped_content
    ADD CONSTRAINT skipped_content_origin_fkey FOREIGN KEY (origin) REFERENCES public.origin(id);


--
-- Name: snapshot_branches snapshot_branches_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snapshot_branches
    ADD CONSTRAINT snapshot_branches_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.snapshot_branch(object_id);


--
-- Name: snapshot_branches snapshot_branches_snapshot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snapshot_branches
    ADD CONSTRAINT snapshot_branches_snapshot_id_fkey FOREIGN KEY (snapshot_id) REFERENCES public.snapshot(object_id);


--
-- PostgreSQL database dump complete
--

