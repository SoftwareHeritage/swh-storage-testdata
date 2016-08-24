--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.4
-- Dumped by pg_dump version 9.5.4

SET statement_timeout = 0;
SET lock_timeout = 0;
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


SET search_path = public, pg_catalog;

--
-- Name: sha1_git; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha1_git AS bytea
	CONSTRAINT sha1_git_check CHECK ((length(VALUE) = 20));


--
-- Name: unix_path; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN unix_path AS bytea;


--
-- Name: content_dir; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_dir AS (
	directory sha1_git,
	path unix_path
);


--
-- Name: object_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE object_type AS ENUM (
    'content',
    'directory',
    'revision',
    'release'
);


--
-- Name: content_occurrence; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_occurrence AS (
	origin_type text,
	origin_url text,
	branch bytea,
	target sha1_git,
	target_type object_type,
	path unix_path
);


--
-- Name: sha1; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha1 AS bytea
	CONSTRAINT sha1_check CHECK ((length(VALUE) = 20));


--
-- Name: sha256; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha256 AS bytea
	CONSTRAINT sha256_check CHECK ((length(VALUE) = 32));


--
-- Name: content_signature; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_signature AS (
	sha1 sha1,
	sha1_git sha1_git,
	sha256 sha256
);


--
-- Name: content_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_status AS ENUM (
    'absent',
    'visible',
    'hidden'
);


--
-- Name: counter; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE counter AS (
	label text,
	value bigint
);


--
-- Name: directory_entry_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE directory_entry_type AS ENUM (
    'file',
    'dir',
    'rev'
);


--
-- Name: file_perms; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN file_perms AS integer;


--
-- Name: directory_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE directory_entry AS (
	dir_id sha1_git,
	type directory_entry_type,
	target sha1_git,
	name unix_path,
	perms file_perms,
	status content_status,
	sha1 sha1,
	sha1_git sha1_git,
	sha256 sha256
);


--
-- Name: entity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE entity_type AS ENUM (
    'organization',
    'group_of_entities',
    'hosting',
    'group_of_persons',
    'person',
    'project'
);


--
-- Name: entity_id; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE entity_id AS (
	id bigint,
	uuid uuid,
	parent uuid,
	name text,
	type entity_type,
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
-- Name: object_found; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE object_found AS (
	sha1_git sha1_git,
	type object_type,
	id bytea,
	object_id bigint
);


--
-- Name: origin_visit_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE origin_visit_status AS ENUM (
    'ongoing',
    'full',
    'partial'
);


--
-- Name: TYPE origin_visit_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE origin_visit_status IS 'Possible visit status';


--
-- Name: release_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE release_entry AS (
	id sha1_git,
	target sha1_git,
	target_type object_type,
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

CREATE TYPE revision_type AS ENUM (
    'git',
    'tar',
    'dsc',
    'svn'
);


--
-- Name: revision_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE revision_entry AS (
	id sha1_git,
	date timestamp with time zone,
	date_offset smallint,
	date_neg_utc_offset boolean,
	committer_date timestamp with time zone,
	committer_date_offset smallint,
	committer_date_neg_utc_offset boolean,
	type revision_type,
	directory sha1_git,
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
-- Name: notify_new_content(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION notify_new_content() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_content', encode(new.sha1, 'hex'));
    return null;
  end;
$$;


--
-- Name: notify_new_directory(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION notify_new_directory() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_directory', encode(new.id, 'hex'));
    return null;
  end;
$$;


--
-- Name: notify_new_origin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION notify_new_origin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_origin', new.id::text);
    return null;
  end;
$$;


--
-- Name: notify_new_origin_visit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION notify_new_origin_visit() RETURNS trigger
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

CREATE FUNCTION notify_new_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_release', encode(new.id, 'hex'));
    return null;
  end;
$$;


--
-- Name: notify_new_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION notify_new_revision() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
    perform pg_notify('new_revision', encode(new.id, 'hex'));
    return null;
  end;
$$;


--
-- Name: notify_new_skipped_content(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION notify_new_skipped_content() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  begin
  perform pg_notify('new_skipped_content', json_build_object(
      'sha1', encode(new.sha1, 'hex'),
      'sha1_git', encode(new.sha1_git, 'hex'),
      'sha256', encode(new.sha256, 'hex')
    )::text);
    return null;
  end;
$$;


--
-- Name: swh_content_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into content (sha1, sha1_git, sha256, length, status)
	select distinct sha1, sha1_git, sha256, length, status
	from tmp_content
	where (sha1, sha1_git, sha256) in
	    (select * from swh_content_missing());
	    -- TODO XXX use postgres 9.5 "UPSERT" support here, when available.
	    -- Specifically, using "INSERT .. ON CONFLICT IGNORE" we can avoid
	    -- the extra swh_content_missing() query here.
    return;
end
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content (
    sha1 sha1 NOT NULL,
    sha1_git sha1_git NOT NULL,
    sha256 sha256 NOT NULL,
    length bigint NOT NULL,
    ctime timestamp with time zone DEFAULT now() NOT NULL,
    status content_status DEFAULT 'visible'::content_status NOT NULL,
    object_id bigint NOT NULL
);


--
-- Name: swh_content_find(sha1, sha1_git, sha256); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_find(sha1 sha1 DEFAULT NULL::bytea, sha1_git sha1_git DEFAULT NULL::bytea, sha256 sha256 DEFAULT NULL::bytea) RETURNS content
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
-- Name: swh_content_find_directory(sha1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_find_directory(content_id sha1) RETURNS content_dir
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
-- Name: swh_content_find_occurrence(sha1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_find_occurrence(content_id sha1) RETURNS content_occurrence
    LANGUAGE plpgsql
    AS $$
declare
    dir content_dir;
    rev sha1_git;
    occ occurrence%ROWTYPE;
    coc content_occurrence;
begin
    -- each step could fail if no results are found, and that's OK
    select * from swh_content_find_directory(content_id)     -- look up directory
	into dir;
    if not found then return null; end if;

    select id from revision where directory = dir.directory  -- look up revision
	limit 1
	into rev;
    if not found then return null; end if;

    select * from swh_revision_find_occurrence(rev)	     -- look up occurrence
	into occ;
    if not found then return null; end if;

    select origin.type, origin.url, occ.branch, occ.target, occ.target_type, dir.path
    from origin
    where origin.id = occ.origin
    into coc;

    return coc;  -- might be NULL
end
$$;


--
-- Name: swh_content_list_by_object_id(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_list_by_object_id(min_excl bigint, max_incl bigint) RETURNS SETOF content
    LANGUAGE sql STABLE
    AS $$
    select * from content
    where object_id > min_excl and object_id <= max_incl
    order by object_id;
$$;


--
-- Name: swh_content_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_missing() RETURNS SETOF content_signature
    LANGUAGE plpgsql
    AS $$
begin
    -- This query is critical for (single-algorithm) hash collision detection,
    -- so we cannot rely only on the fact that a single hash (e.g., sha1) is
    -- missing from the table content to conclude that a given content is
    -- missing. Ideally, we would want to (try to) add to content all entries
    -- in tmp_content that, when considering all columns together, are missing
    -- from content.
    --
    -- But doing that naively would require a *compound* index on all checksum
    -- columns; that index would not be significantly smaller than the content
    -- table itself, and therefore won't be used. Therefore we union together
    -- all contents that differ on at least one column from what is already
    -- available. If there is a collision on some (but not all) columns, the
    -- relevant tmp_content entry will be included in the set of content to be
    -- added, causing a downstream violation of unicity constraint.
    return query
	(select sha1, sha1_git, sha256 from tmp_content as tmp
	 where not exists
	     (select 1 from content as c where c.sha1 = tmp.sha1))
	union
	(select sha1, sha1_git, sha256 from tmp_content as tmp
	 where not exists
	     (select 1 from content as c where c.sha1_git = tmp.sha1_git))
	union
	(select sha1, sha1_git, sha256 from tmp_content as tmp
	 where not exists
	     (select 1 from content as c where c.sha256 = tmp.sha256));
    return;
end
$$;


--
-- Name: swh_content_missing_per_sha1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_missing_per_sha1() RETURNS SETOF sha1
    LANGUAGE plpgsql
    AS $$
begin
    return query
           (select id::sha1
            from tmp_bytea as tmp
            where not exists
            (select 1 from content as c where c.sha1=tmp.id));
end
$$;


--
-- Name: swh_directory_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_add() RETURNS void
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
-- Name: swh_directory_entry_add(directory_entry_type); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_entry_add(typ directory_entry_type) RETURNS void
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
-- Name: directory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE directory (
    id sha1_git NOT NULL,
    dir_entries bigint[],
    file_entries bigint[],
    rev_entries bigint[],
    object_id bigint NOT NULL
);


--
-- Name: swh_directory_get(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_get() RETURNS SETOF directory
    LANGUAGE plpgsql
    AS $$
begin
    return query
	select d.*
        from tmp_directory t
        inner join directory d on t.id = d.id;
    return;
end
$$;


--
-- Name: swh_directory_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_missing() RETURNS SETOF sha1_git
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
-- Name: swh_directory_walk(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_walk(walked_dir_id sha1_git) RETURNS SETOF directory_entry
    LANGUAGE sql STABLE
    AS $$
    with recursive entries as (
        select dir_id, type, target, name, perms, status, sha1, sha1_git,
               sha256
        from swh_directory_walk_one(walked_dir_id)
        union all
        select dir_id, type, target, (dirname || '/' || name)::unix_path as name,
               perms, status, sha1, sha1_git, sha256
        from (select (swh_directory_walk_one(dirs.target)).*, dirs.name as dirname
              from (select target, name from entries where type = 'dir') as dirs) as with_parent
    )
    select dir_id, type, target, name, perms, status, sha1, sha1_git, sha256
    from entries
$$;


--
-- Name: swh_directory_walk_one(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_walk_one(walked_dir_id sha1_git) RETURNS SETOF directory_entry
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
            NULL::sha1, NULL::sha1_git, NULL::sha256
     from ls_d
     left join directory_entry_dir e on ls_d.entry_id = e.id)
    union
    (select dir_id, 'file'::directory_entry_type as type,
            e.target, e.name, e.perms, c.status,
            c.sha1, c.sha1_git, c.sha256
     from ls_f
     left join directory_entry_file e on ls_f.entry_id = e.id
     left join content c on e.target = c.sha1_git)
    union
    (select dir_id, 'rev'::directory_entry_type as type,
            e.target, e.name, e.perms, NULL::content_status,
            NULL::sha1, NULL::sha1_git, NULL::sha256
     from ls_r
     left join directory_entry_rev e on ls_r.entry_id = e.id)
    order by name;
$$;


--
-- Name: swh_entity_from_tmp_entity_lister(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_entity_from_tmp_entity_lister() RETURNS SETOF entity_id
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

CREATE TABLE entity (
    uuid uuid NOT NULL,
    parent uuid,
    name text NOT NULL,
    type entity_type NOT NULL,
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

CREATE FUNCTION swh_entity_get(entity_uuid uuid) RETURNS SETOF entity
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

CREATE FUNCTION swh_entity_history_add() RETURNS void
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
-- Name: swh_find_directory_entry_by_path(sha1_git, bytea[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_find_directory_entry_by_path(walked_dir_id sha1_git, dir_or_content_path bytea[]) RETURNS directory_entry
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

CREATE FUNCTION swh_mktemp(tblname regclass) RETURNS void
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
-- Name: swh_mktemp_bytea(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_bytea() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_bytea (
      id bytea
    ) on commit drop;
$$;


--
-- Name: swh_mktemp_dir_entry(regclass); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_dir_entry(tblname regclass) RETURNS void
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

CREATE FUNCTION swh_mktemp_entity_history() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_entity_history (
        like entity_history including defaults) on commit drop;
    alter table tmp_entity_history drop column id;
$$;


--
-- Name: swh_mktemp_entity_lister(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_entity_lister() RETURNS void
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

CREATE FUNCTION swh_mktemp_occurrence_history() RETURNS void
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

CREATE FUNCTION swh_mktemp_release() RETURNS void
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

CREATE FUNCTION swh_mktemp_revision() RETURNS void
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
-- Name: swh_object_find_by_sha1_git(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_object_find_by_sha1_git() RETURNS SETOF object_found
    LANGUAGE plpgsql
    AS $$
begin
    return query
    with known_objects as ((
        select id as sha1_git, 'release'::object_type as type, id, object_id from release r
        where exists (select 1 from tmp_bytea t where t.id = r.id)
    ) union all (
        select id as sha1_git, 'revision'::object_type as type, id, object_id from revision r
        where exists (select 1 from tmp_bytea t where t.id = r.id)
    ) union all (
        select id as sha1_git, 'directory'::object_type as type, id, object_id from directory d
        where exists (select 1 from tmp_bytea t where t.id = d.id)
    ) union all (
        select sha1_git as sha1_git, 'content'::object_type as type, sha1 as id, object_id from content c
        where exists (select 1 from tmp_bytea t where t.id = c.sha1_git)
    ))
    select t.id::sha1_git as sha1_git, k.type, k.id, k.object_id from tmp_bytea t
      left join known_objects k on t.id = k.sha1_git;
end
$$;


--
-- Name: occurrence_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE occurrence_history (
    origin bigint NOT NULL,
    branch bytea NOT NULL,
    target sha1_git NOT NULL,
    target_type object_type NOT NULL,
    object_id bigint NOT NULL,
    visits bigint[] NOT NULL
);


--
-- Name: swh_occurrence_get_by(bigint, bytea, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_occurrence_get_by(origin_id bigint, branch_name bytea DEFAULT NULL::bytea, date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS SETOF occurrence_history
    LANGUAGE plpgsql
    AS $$
declare
    filters text[] := array[] :: text[];  -- AND-clauses used to filter content
    visit_id bigint;
    q text;
begin
    if origin_id is not null then
        filters := filters || format('origin = %L', origin_id);
    end if;
    if branch_name is not null then
        filters := filters || format('branch = %L', branch_name);
    end if;
    if date is not null then
        if origin_id is null then
            raise exception 'Needs an origin_id to filter by date.';
        end if;
        select visit from swh_visit_find_by_date(origin_id, date) into visit_id;
        if visit_id is null then
            return;
        end if;
        filters := filters || format('%L = any(visits)', visit_id);
    end if;

    if cardinality(filters) = 0 then
        raise exception 'At least one filter amongst (origin_id, branch_name, date) is needed';
    else
        q = format('select * ' ||
                   'from occurrence_history ' ||
                   'where %s',
	        array_to_string(filters, ' and '));
        return query execute q;
    end if;
end
$$;


--
-- Name: swh_occurrence_history_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_occurrence_history_add() RETURNS void
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

CREATE FUNCTION swh_occurrence_update_all() RETURNS void
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

CREATE FUNCTION swh_occurrence_update_for_origin(origin_id bigint) RETURNS void
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
-- Name: swh_origin_visit_add(bigint, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_origin_visit_add(origin_id bigint, date timestamp with time zone) RETURNS bigint
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

CREATE FUNCTION swh_person_add_from_release() RETURNS void
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

CREATE FUNCTION swh_person_add_from_revision() RETURNS void
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

CREATE FUNCTION swh_release_add() RETURNS void
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
-- Name: swh_release_get(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_release_get() RETURNS SETOF release_entry
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select r.id, r.target, r.target_type, r.date, r.date_offset, r.date_neg_utc_offset, r.name, r.comment,
               r.synthetic, p.id as author_id, p.fullname as author_fullname, p.name as author_name, p.email as author_email, r.object_id
        from tmp_bytea t
        inner join release r on t.id = r.id
        inner join person p on p.id = r.author;
    return;
end
$$;


--
-- Name: swh_release_get_by(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_release_get_by(origin_id bigint) RETURNS SETOF release_entry
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

CREATE FUNCTION swh_release_list_by_object_id(min_excl bigint, max_incl bigint) RETURNS SETOF release_entry
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
-- Name: swh_release_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_release_missing() RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
begin
  return query
    select id::sha1_git from tmp_bytea t
    where not exists (
      select 1 from release r
      where r.id = t.id);
end
$$;


--
-- Name: swh_revision_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_add() RETURNS void
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
-- Name: occurrence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE occurrence (
    origin bigint NOT NULL,
    branch bytea NOT NULL,
    target sha1_git NOT NULL,
    target_type object_type NOT NULL
);


--
-- Name: swh_revision_find_occurrence(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_find_occurrence(revision_id sha1_git) RETURNS occurrence
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
-- Name: swh_revision_get(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_get() RETURNS SETOF revision_entry
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select r.id, r.date, r.date_offset, r.date_neg_utc_offset,
               r.committer_date, r.committer_date_offset, r.committer_date_neg_utc_offset,
               r.type, r.directory, r.message,
               a.id, a.fullname, a.name, a.email, c.id, c.fullname, c.name, c.email, r.metadata, r.synthetic,
         array(select rh.parent_id::bytea from revision_history rh where rh.id = t.id order by rh.parent_rank)
                   as parents, r.object_id
        from tmp_bytea t
        left join revision r on t.id = r.id
        left join person a on a.id = r.author
        left join person c on c.id = r.committer;
    return;
end
$$;


--
-- Name: swh_revision_get_by(bigint, bytea, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_get_by(origin_id bigint, branch_name bytea DEFAULT NULL::bytea, date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS SETOF revision_entry
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

CREATE FUNCTION swh_revision_list(root_revisions bytea[], num_revs bigint DEFAULT NULL::bigint) RETURNS TABLE(id sha1_git, parents bytea[])
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

CREATE FUNCTION swh_revision_list_by_object_id(min_excl bigint, max_incl bigint) RETURNS SETOF revision_entry
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

CREATE FUNCTION swh_revision_list_children(root_revisions bytea[], num_revs bigint DEFAULT NULL::bigint) RETURNS TABLE(id sha1_git, parents bytea[])
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

CREATE FUNCTION swh_revision_log(root_revisions bytea[], num_revs bigint DEFAULT NULL::bigint) RETURNS SETOF revision_entry
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
-- Name: swh_revision_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_missing() RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select id::sha1_git from tmp_bytea t
	where not exists (
	    select 1 from revision r
	    where r.id = t.id);
    return;
end
$$;


--
-- Name: swh_skipped_content_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_skipped_content_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into skipped_content (sha1, sha1_git, sha256, length, status, reason, origin)
	select distinct sha1, sha1_git, sha256, length, status, reason, origin
	from tmp_skipped_content
	where (coalesce(sha1, ''), coalesce(sha1_git, ''), coalesce(sha256, '')) in
	    (select coalesce(sha1, ''), coalesce(sha1_git, ''), coalesce(sha256, '') from swh_skipped_content_missing());
	    -- TODO XXX use postgres 9.5 "UPSERT" support here, when available.
	    -- Specifically, using "INSERT .. ON CONFLICT IGNORE" we can avoid
	    -- the extra swh_content_missing() query here.
    return;
end
$$;


--
-- Name: swh_skipped_content_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_skipped_content_missing() RETURNS SETOF content_signature
    LANGUAGE plpgsql
    AS $$
begin
    return query
	select sha1, sha1_git, sha256 from tmp_skipped_content t
	where not exists
	(select 1 from skipped_content s where
	    s.sha1 is not distinct from t.sha1 and
	    s.sha1_git is not distinct from t.sha1_git and
	    s.sha256 is not distinct from t.sha256);
    return;
end
$$;


--
-- Name: swh_stat_counters(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_stat_counters() RETURNS SETOF counter
    LANGUAGE sql STABLE
    AS $$
    select relname::text as label, reltuples::bigint as value
    from pg_class
    where oid in (
        'public.content'::regclass,
        'public.directory'::regclass,
        'public.directory_entry_dir'::regclass,
        'public.directory_entry_file'::regclass,
        'public.directory_entry_rev'::regclass,
        'public.occurrence'::regclass,
        'public.occurrence_history'::regclass,
        'public.origin'::regclass,
        'public.person'::regclass,
        'public.entity'::regclass,
        'public.entity_history'::regclass,
        'public.release'::regclass,
        'public.revision'::regclass,
        'public.revision_history'::regclass,
        'public.skipped_content'::regclass
    );
$$;


--
-- Name: swh_update_entity_from_entity_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_update_entity_from_entity_history() RETURNS trigger
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

CREATE TABLE origin_visit (
    origin bigint NOT NULL,
    visit bigint NOT NULL,
    date timestamp with time zone NOT NULL,
    status origin_visit_status NOT NULL,
    metadata jsonb
);


--
-- Name: COLUMN origin_visit.origin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN origin_visit.origin IS 'Visited origin';


--
-- Name: COLUMN origin_visit.visit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN origin_visit.visit IS 'Visit number the visit occurred for that origin';


--
-- Name: COLUMN origin_visit.date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN origin_visit.date IS 'Visit date for that origin';


--
-- Name: COLUMN origin_visit.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN origin_visit.status IS 'Visit status for that origin';


--
-- Name: COLUMN origin_visit.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN origin_visit.metadata IS 'Metadata associated with the visit';


--
-- Name: swh_visit_find_by_date(bigint, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_visit_find_by_date(origin bigint, visit_date timestamp with time zone DEFAULT now()) RETURNS origin_visit
    LANGUAGE sql STABLE
    AS $$
  with closest_two_visits as ((
    select origin_visit, (date - visit_date) as interval
    from origin_visit
    where date >= visit_date
    order by date asc
    limit 1
  ) union (
    select origin_visit, (visit_date - date) as interval
    from origin_visit
    where date < visit_date
    order by date desc
    limit 1
  )) select (origin_visit).* from closest_two_visits order by interval limit 1
$$;


--
-- Name: swh_visit_get(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_visit_get(origin bigint) RETURNS origin_visit
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

CREATE SEQUENCE content_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE content_object_id_seq OWNED BY content.object_id;


--
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE dbversion (
    version integer NOT NULL,
    release timestamp with time zone,
    description text
);


--
-- Name: directory_entry_dir; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE directory_entry_dir (
    id bigint NOT NULL,
    target sha1_git,
    name unix_path,
    perms file_perms
);


--
-- Name: directory_entry_dir_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE directory_entry_dir_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_entry_dir_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE directory_entry_dir_id_seq OWNED BY directory_entry_dir.id;


--
-- Name: directory_entry_file; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE directory_entry_file (
    id bigint NOT NULL,
    target sha1_git,
    name unix_path,
    perms file_perms
);


--
-- Name: directory_entry_file_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE directory_entry_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_entry_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE directory_entry_file_id_seq OWNED BY directory_entry_file.id;


--
-- Name: directory_entry_rev; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE directory_entry_rev (
    id bigint NOT NULL,
    target sha1_git,
    name unix_path,
    perms file_perms
);


--
-- Name: directory_entry_rev_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE directory_entry_rev_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_entry_rev_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE directory_entry_rev_id_seq OWNED BY directory_entry_rev.id;


--
-- Name: directory_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE directory_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE directory_object_id_seq OWNED BY directory.object_id;


--
-- Name: entity_equivalence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE entity_equivalence (
    entity1 uuid NOT NULL,
    entity2 uuid NOT NULL,
    CONSTRAINT order_entities CHECK ((entity1 < entity2))
);


--
-- Name: entity_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE entity_history (
    id bigint NOT NULL,
    uuid uuid,
    parent uuid,
    name text NOT NULL,
    type entity_type NOT NULL,
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

CREATE SEQUENCE entity_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE entity_history_id_seq OWNED BY entity_history.id;


--
-- Name: fetch_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE fetch_history (
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

CREATE SEQUENCE fetch_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fetch_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE fetch_history_id_seq OWNED BY fetch_history.id;


--
-- Name: list_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE list_history (
    id bigint NOT NULL,
    entity uuid,
    date timestamp with time zone NOT NULL,
    status boolean,
    result jsonb,
    stdout text,
    stderr text,
    duration interval
);


--
-- Name: list_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE list_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE list_history_id_seq OWNED BY list_history.id;


--
-- Name: listable_entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE listable_entity (
    uuid uuid NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    list_engine text,
    list_url text,
    list_params jsonb,
    latest_list timestamp with time zone
);


--
-- Name: occurrence_history_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE occurrence_history_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: occurrence_history_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE occurrence_history_object_id_seq OWNED BY occurrence_history.object_id;


--
-- Name: origin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE origin (
    id bigint NOT NULL,
    type text,
    url text NOT NULL,
    lister uuid,
    project uuid
);


--
-- Name: origin_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE origin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: origin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE origin_id_seq OWNED BY origin.id;


--
-- Name: person; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE person (
    id bigint NOT NULL,
    fullname bytea NOT NULL,
    name bytea,
    email bytea
);


--
-- Name: person_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE person_id_seq OWNED BY person.id;


--
-- Name: release; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE release (
    id sha1_git NOT NULL,
    target sha1_git,
    target_type object_type,
    date timestamp with time zone,
    date_offset smallint,
    date_neg_utc_offset boolean,
    name bytea,
    comment bytea,
    author bigint,
    synthetic boolean DEFAULT false NOT NULL,
    object_id bigint NOT NULL
);


--
-- Name: release_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE release_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: release_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE release_object_id_seq OWNED BY release.object_id;


--
-- Name: revision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE revision (
    id sha1_git NOT NULL,
    date timestamp with time zone,
    date_offset smallint,
    date_neg_utc_offset boolean,
    committer_date timestamp with time zone,
    committer_date_offset smallint,
    committer_date_neg_utc_offset boolean,
    type revision_type NOT NULL,
    directory sha1_git,
    message bytea,
    author bigint,
    committer bigint,
    metadata jsonb,
    synthetic boolean DEFAULT false NOT NULL,
    object_id bigint NOT NULL
);


--
-- Name: revision_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE revision_history (
    id sha1_git NOT NULL,
    parent_id sha1_git,
    parent_rank integer DEFAULT 0 NOT NULL
);


--
-- Name: revision_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE revision_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: revision_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE revision_object_id_seq OWNED BY revision.object_id;


--
-- Name: skipped_content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE skipped_content (
    sha1 sha1,
    sha1_git sha1_git,
    sha256 sha256,
    length bigint NOT NULL,
    ctime timestamp with time zone DEFAULT now() NOT NULL,
    status content_status DEFAULT 'absent'::content_status NOT NULL,
    reason text NOT NULL,
    origin bigint,
    object_id bigint NOT NULL
);


--
-- Name: skipped_content_object_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE skipped_content_object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: skipped_content_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE skipped_content_object_id_seq OWNED BY skipped_content.object_id;


--
-- Name: object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY content ALTER COLUMN object_id SET DEFAULT nextval('content_object_id_seq'::regclass);


--
-- Name: object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory ALTER COLUMN object_id SET DEFAULT nextval('directory_object_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_dir ALTER COLUMN id SET DEFAULT nextval('directory_entry_dir_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_file ALTER COLUMN id SET DEFAULT nextval('directory_entry_file_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_rev ALTER COLUMN id SET DEFAULT nextval('directory_entry_rev_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_history ALTER COLUMN id SET DEFAULT nextval('entity_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY fetch_history ALTER COLUMN id SET DEFAULT nextval('fetch_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history ALTER COLUMN id SET DEFAULT nextval('list_history_id_seq'::regclass);


--
-- Name: object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history ALTER COLUMN object_id SET DEFAULT nextval('occurrence_history_object_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin ALTER COLUMN id SET DEFAULT nextval('origin_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person ALTER COLUMN id SET DEFAULT nextval('person_id_seq'::regclass);


--
-- Name: object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY release ALTER COLUMN object_id SET DEFAULT nextval('release_object_id_seq'::regclass);


--
-- Name: object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision ALTER COLUMN object_id SET DEFAULT nextval('revision_object_id_seq'::regclass);


--
-- Name: object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY skipped_content ALTER COLUMN object_id SET DEFAULT nextval('skipped_content_object_id_seq'::regclass);


--
-- Data for Name: content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content (sha1, sha1_git, sha256, length, ctime, status, object_id) FROM stdin;
\.


--
-- Name: content_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('content_object_id_seq', 1, false);


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
76	2016-08-24 14:24:12.618545+02	Work In Progress
\.


--
-- Data for Name: directory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory (id, dir_entries, file_entries, rev_entries, object_id) FROM stdin;
\.


--
-- Data for Name: directory_entry_dir; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_entry_dir (id, target, name, perms) FROM stdin;
\.


--
-- Name: directory_entry_dir_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('directory_entry_dir_id_seq', 1, false);


--
-- Data for Name: directory_entry_file; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_entry_file (id, target, name, perms) FROM stdin;
\.


--
-- Name: directory_entry_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('directory_entry_file_id_seq', 1, false);


--
-- Data for Name: directory_entry_rev; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_entry_rev (id, target, name, perms) FROM stdin;
\.


--
-- Name: directory_entry_rev_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('directory_entry_rev_id_seq', 1, false);


--
-- Name: directory_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('directory_object_id_seq', 1, false);


--
-- Data for Name: entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY entity (uuid, parent, name, type, description, homepage, active, generated, lister_metadata, metadata, last_seen, last_id) FROM stdin;
5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	1
6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	2
7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	2016-08-24 14:24:12.618545+02	3
4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	4
5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	5
4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	6
aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	7
34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	8
e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	9
9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	10
ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	2016-08-24 14:24:12.618545+02	11
\.


--
-- Data for Name: entity_equivalence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY entity_equivalence (entity1, entity2) FROM stdin;
\.


--
-- Data for Name: entity_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY entity_history (id, uuid, parent, name, type, description, homepage, active, generated, lister_metadata, metadata, validity) FROM stdin;
1	5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
2	6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
3	7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
4	4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
5	5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
6	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
8	34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
9	e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
10	9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
11	ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	{"2016-08-24 14:24:12.618545+02"}
\.


--
-- Name: entity_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('entity_history_id_seq', 11, true);


--
-- Data for Name: fetch_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY fetch_history (id, origin, date, status, result, stdout, stderr, duration) FROM stdin;
\.


--
-- Name: fetch_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('fetch_history_id_seq', 1, false);


--
-- Data for Name: list_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY list_history (id, entity, date, status, result, stdout, stderr, duration) FROM stdin;
\.


--
-- Name: list_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('list_history_id_seq', 1, false);


--
-- Data for Name: listable_entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY listable_entity (uuid, enabled, list_engine, list_url, list_params, latest_list) FROM stdin;
34bd6b1b-463f-43e5-a697-785107f598e4	t	swh.lister.github	\N	\N	\N
\.


--
-- Data for Name: occurrence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY occurrence (origin, branch, target, target_type) FROM stdin;
\.


--
-- Data for Name: occurrence_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY occurrence_history (origin, branch, target, target_type, object_id, visits) FROM stdin;
\.


--
-- Name: occurrence_history_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('occurrence_history_object_id_seq', 1, false);


--
-- Data for Name: origin; Type: TABLE DATA; Schema: public; Owner: -
--

COPY origin (id, type, url, lister, project) FROM stdin;
\.


--
-- Name: origin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('origin_id_seq', 1, false);


--
-- Data for Name: origin_visit; Type: TABLE DATA; Schema: public; Owner: -
--

COPY origin_visit (origin, visit, date, status, metadata) FROM stdin;
\.


--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: -
--

COPY person (id, fullname, name, email) FROM stdin;
\.


--
-- Name: person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('person_id_seq', 1, false);


--
-- Data for Name: release; Type: TABLE DATA; Schema: public; Owner: -
--

COPY release (id, target, target_type, date, date_offset, date_neg_utc_offset, name, comment, author, synthetic, object_id) FROM stdin;
\.


--
-- Name: release_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('release_object_id_seq', 1, false);


--
-- Data for Name: revision; Type: TABLE DATA; Schema: public; Owner: -
--

COPY revision (id, date, date_offset, date_neg_utc_offset, committer_date, committer_date_offset, committer_date_neg_utc_offset, type, directory, message, author, committer, metadata, synthetic, object_id) FROM stdin;
\.


--
-- Data for Name: revision_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY revision_history (id, parent_id, parent_rank) FROM stdin;
\.


--
-- Name: revision_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('revision_object_id_seq', 1, false);


--
-- Data for Name: skipped_content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY skipped_content (sha1, sha1_git, sha256, length, ctime, status, reason, origin, object_id) FROM stdin;
\.


--
-- Name: skipped_content_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('skipped_content_object_id_seq', 1, false);


--
-- Name: content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content
    ADD CONSTRAINT content_pkey PRIMARY KEY (sha1);


--
-- Name: dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: directory_entry_dir_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_dir
    ADD CONSTRAINT directory_entry_dir_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_file
    ADD CONSTRAINT directory_entry_file_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_rev_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_rev
    ADD CONSTRAINT directory_entry_rev_pkey PRIMARY KEY (id);


--
-- Name: directory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory
    ADD CONSTRAINT directory_pkey PRIMARY KEY (id);


--
-- Name: entity_equivalence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_equivalence
    ADD CONSTRAINT entity_equivalence_pkey PRIMARY KEY (entity1, entity2);


--
-- Name: entity_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_history
    ADD CONSTRAINT entity_history_pkey PRIMARY KEY (id);


--
-- Name: entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (uuid);


--
-- Name: fetch_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY fetch_history
    ADD CONSTRAINT fetch_history_pkey PRIMARY KEY (id);


--
-- Name: list_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history
    ADD CONSTRAINT list_history_pkey PRIMARY KEY (id);


--
-- Name: listable_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY listable_entity
    ADD CONSTRAINT listable_entity_pkey PRIMARY KEY (uuid);


--
-- Name: occurrence_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_pkey PRIMARY KEY (object_id);


--
-- Name: occurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence
    ADD CONSTRAINT occurrence_pkey PRIMARY KEY (origin, branch);


--
-- Name: origin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin
    ADD CONSTRAINT origin_pkey PRIMARY KEY (id);


--
-- Name: origin_visit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin_visit
    ADD CONSTRAINT origin_visit_pkey PRIMARY KEY (origin, visit);


--
-- Name: person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: release_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_pkey PRIMARY KEY (id);


--
-- Name: revision_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision_history
    ADD CONSTRAINT revision_history_pkey PRIMARY KEY (id, parent_rank);


--
-- Name: revision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision
    ADD CONSTRAINT revision_pkey PRIMARY KEY (id);


--
-- Name: skipped_content_sha1_sha1_git_sha256_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY skipped_content
    ADD CONSTRAINT skipped_content_sha1_sha1_git_sha256_key UNIQUE (sha1, sha1_git, sha256);


--
-- Name: content_ctime_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_ctime_idx ON content USING btree (ctime);


--
-- Name: content_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_object_id_idx ON content USING btree (object_id);


--
-- Name: content_sha1_git_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX content_sha1_git_idx ON content USING btree (sha1_git);


--
-- Name: content_sha256_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX content_sha256_idx ON content USING btree (sha256);


--
-- Name: directory_dir_entries_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_dir_entries_idx ON directory USING gin (dir_entries);


--
-- Name: directory_entry_dir_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX directory_entry_dir_target_name_perms_idx ON directory_entry_dir USING btree (target, name, perms);


--
-- Name: directory_entry_file_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX directory_entry_file_target_name_perms_idx ON directory_entry_file USING btree (target, name, perms);


--
-- Name: directory_entry_rev_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX directory_entry_rev_target_name_perms_idx ON directory_entry_rev USING btree (target, name, perms);


--
-- Name: directory_file_entries_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_file_entries_idx ON directory USING gin (file_entries);


--
-- Name: directory_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_object_id_idx ON directory USING btree (object_id);


--
-- Name: directory_rev_entries_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_rev_entries_idx ON directory USING gin (rev_entries);


--
-- Name: entity_history_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_history_name_idx ON entity_history USING btree (name);


--
-- Name: entity_history_uuid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_history_uuid_idx ON entity_history USING btree (uuid);


--
-- Name: entity_lister_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_lister_metadata_idx ON entity USING gin (lister_metadata jsonb_path_ops);


--
-- Name: entity_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_name_idx ON entity USING btree (name);


--
-- Name: occurrence_history_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX occurrence_history_object_id_idx ON occurrence_history USING btree (object_id);


--
-- Name: occurrence_history_origin_branch_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX occurrence_history_origin_branch_idx ON occurrence_history USING btree (origin, branch);


--
-- Name: occurrence_history_origin_branch_target_target_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX occurrence_history_origin_branch_target_target_type_idx ON occurrence_history USING btree (origin, branch, target, target_type);


--
-- Name: occurrence_history_target_target_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX occurrence_history_target_target_type_idx ON occurrence_history USING btree (target, target_type);


--
-- Name: origin_type_url_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_type_url_idx ON origin USING btree (type, url);


--
-- Name: origin_visit_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_visit_date_idx ON origin_visit USING btree (date);


--
-- Name: person_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_email_idx ON person USING btree (email);


--
-- Name: person_fullname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX person_fullname_idx ON person USING btree (fullname);


--
-- Name: person_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX person_name_idx ON person USING btree (name);


--
-- Name: release_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX release_object_id_idx ON release USING btree (object_id);


--
-- Name: release_target_target_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX release_target_target_type_idx ON release USING btree (target, target_type);


--
-- Name: revision_directory_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revision_directory_idx ON revision USING btree (directory);


--
-- Name: revision_history_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revision_history_parent_id_idx ON revision_history USING btree (parent_id);


--
-- Name: revision_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revision_object_id_idx ON revision USING btree (object_id);


--
-- Name: skipped_content_object_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX skipped_content_object_id_idx ON skipped_content USING btree (object_id);


--
-- Name: skipped_content_sha1_git_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX skipped_content_sha1_git_idx ON skipped_content USING btree (sha1_git);


--
-- Name: skipped_content_sha1_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX skipped_content_sha1_idx ON skipped_content USING btree (sha1);


--
-- Name: skipped_content_sha256_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX skipped_content_sha256_idx ON skipped_content USING btree (sha256);


--
-- Name: notify_new_content; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_content AFTER INSERT ON content FOR EACH ROW EXECUTE PROCEDURE notify_new_content();


--
-- Name: notify_new_directory; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_directory AFTER INSERT ON directory FOR EACH ROW EXECUTE PROCEDURE notify_new_directory();


--
-- Name: notify_new_origin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_origin AFTER INSERT ON origin FOR EACH ROW EXECUTE PROCEDURE notify_new_origin();


--
-- Name: notify_new_origin_visit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_origin_visit AFTER INSERT ON origin_visit FOR EACH ROW EXECUTE PROCEDURE notify_new_origin_visit();


--
-- Name: notify_new_release; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_release AFTER INSERT ON release FOR EACH ROW EXECUTE PROCEDURE notify_new_release();


--
-- Name: notify_new_revision; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_revision AFTER INSERT ON revision FOR EACH ROW EXECUTE PROCEDURE notify_new_revision();


--
-- Name: notify_new_skipped_content; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_skipped_content AFTER INSERT ON skipped_content FOR EACH ROW EXECUTE PROCEDURE notify_new_skipped_content();


--
-- Name: update_entity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_entity AFTER INSERT OR UPDATE ON entity_history FOR EACH ROW EXECUTE PROCEDURE swh_update_entity_from_entity_history();


--
-- Name: entity_equivalence_entity1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_equivalence
    ADD CONSTRAINT entity_equivalence_entity1_fkey FOREIGN KEY (entity1) REFERENCES entity(uuid);


--
-- Name: entity_equivalence_entity2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_equivalence
    ADD CONSTRAINT entity_equivalence_entity2_fkey FOREIGN KEY (entity2) REFERENCES entity(uuid);


--
-- Name: entity_last_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_last_id_fkey FOREIGN KEY (last_id) REFERENCES entity_history(id);


--
-- Name: entity_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_parent_fkey FOREIGN KEY (parent) REFERENCES entity(uuid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: fetch_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY fetch_history
    ADD CONSTRAINT fetch_history_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: list_history_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history
    ADD CONSTRAINT list_history_entity_fkey FOREIGN KEY (entity) REFERENCES listable_entity(uuid);


--
-- Name: listable_entity_uuid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY listable_entity
    ADD CONSTRAINT listable_entity_uuid_fkey FOREIGN KEY (uuid) REFERENCES entity(uuid);


--
-- Name: occurrence_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: occurrence_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence
    ADD CONSTRAINT occurrence_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: origin_lister_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin
    ADD CONSTRAINT origin_lister_fkey FOREIGN KEY (lister) REFERENCES listable_entity(uuid);


--
-- Name: origin_project_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin
    ADD CONSTRAINT origin_project_fkey FOREIGN KEY (project) REFERENCES entity(uuid);


--
-- Name: origin_visit_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin_visit
    ADD CONSTRAINT origin_visit_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: release_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_author_fkey FOREIGN KEY (author) REFERENCES person(id);


--
-- Name: revision_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision
    ADD CONSTRAINT revision_author_fkey FOREIGN KEY (author) REFERENCES person(id);


--
-- Name: revision_committer_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision
    ADD CONSTRAINT revision_committer_fkey FOREIGN KEY (committer) REFERENCES person(id);


--
-- Name: revision_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision_history
    ADD CONSTRAINT revision_history_id_fkey FOREIGN KEY (id) REFERENCES revision(id);


--
-- Name: skipped_content_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY skipped_content
    ADD CONSTRAINT skipped_content_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

