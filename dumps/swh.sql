--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

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
-- Name: content_occurrence; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_occurrence AS (
	origin_type text,
	origin_url text,
	branch text,
	revision_id sha1_git,
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
	atime timestamp with time zone,
	mtime timestamp with time zone,
	ctime timestamp with time zone
);


--
-- Name: revision_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE revision_type AS ENUM (
    'git',
    'tar',
    'dsc'
);


--
-- Name: revision_log_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE revision_log_entry AS (
	id sha1_git,
	date timestamp with time zone,
	date_offset smallint,
	committer_date timestamp with time zone,
	committer_date_offset smallint,
	type revision_type,
	directory sha1_git,
	message bytea,
	author_name text,
	author_email text,
	committer_name text,
	committer_email text
);


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
-- Name: content; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE content (
    sha1 sha1 NOT NULL,
    sha1_git sha1_git NOT NULL,
    sha256 sha256 NOT NULL,
    length bigint NOT NULL,
    ctime timestamp with time zone DEFAULT now() NOT NULL,
    status content_status DEFAULT 'visible'::content_status NOT NULL
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
    LANGUAGE plpgsql
    AS $$
declare
    d content_dir;
begin
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
    select dir_id, name from path order by depth desc limit 1
    into strict d;

    return d;
end
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
	into strict dir;
    select id from revision where directory = dir.directory  -- look up revision
	limit 1
	into strict rev;
    select * from swh_revision_find_occurrence(rev)	     -- look up occurrence
	into strict occ;

    select origin.type, origin.url, occ.branch, rev, dir.path
    from origin
    where origin.id = occ.origin
    into strict coc;

    return coc;
end
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
-- Name: swh_directory_entry_add(directory_entry_type); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_entry_add(typ directory_entry_type) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
    execute format('
    insert into directory_entry_%1$s (target, name, perms, atime, mtime, ctime)
    select distinct t.target, t.name, t.perms, t.atime, t.mtime, t.ctime
    from tmp_directory_entry_%1$s t
    where not exists (
    select 1
    from directory_entry_%1$s i
    where t.target = i.target and t.name = i.name and t.perms = i.perms and
       t.atime is not distinct from i.atime and
       t.mtime is not distinct from i.mtime and
       t.ctime is not distinct from i.ctime)
   ', typ);

    execute format('
    with new_entries as (
	select t.dir_id, array_agg(i.id) as entries
	from tmp_directory_entry_%1$s t
	inner join directory_entry_%1$s i
	on t.target = i.target and t.name = i.name and t.perms = i.perms and
	   t.atime is not distinct from i.atime and
	   t.mtime is not distinct from i.mtime and
	   t.ctime is not distinct from i.ctime
	group by t.dir_id
    )
    update directory as d
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

CREATE FUNCTION swh_directory_missing() RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
begin
    return query
	select id from tmp_directory
	except
	select id from directory;
    return;
end
$$;


--
-- Name: swh_directory_walk_one(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_walk_one(walked_dir_id sha1_git) RETURNS SETOF directory_entry
    LANGUAGE plpgsql
    AS $$
begin
    return query
        with dir as (
	    select id as dir_id, dir_entries, file_entries, rev_entries
	    from directory
	    where id = walked_dir_id),
	ls_d as (select dir_id, unnest(dir_entries) as entry_id from dir),
	ls_f as (select dir_id, unnest(file_entries) as entry_id from dir),
	ls_r as (select dir_id, unnest(rev_entries) as entry_id from dir)
	(select dir_id, 'dir'::directory_entry_type as type,
	        target, name, perms, atime, mtime, ctime
	 from ls_d
	 left join directory_entry_dir d on ls_d.entry_id = d.id)
        union
        (select dir_id, 'file'::directory_entry_type as type,
	        target, name, perms, atime, mtime, ctime
	 from ls_f
	 left join directory_entry_file d on ls_f.entry_id = d.id)
        union
        (select dir_id, 'rev'::directory_entry_type as type,
	        target, name, perms, atime, mtime, ctime
	 from ls_r
	 left join directory_entry_rev d on ls_r.entry_id = d.id)
        order by name;
    return;
end
$$;


--
-- Name: swh_mktemp(regclass); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp(tblname regclass) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    execute format('
	create temporary table tmp_%I
	    (like %I including defaults)
	    on commit drop
	', tblname, tblname);
    return;
end
$$;


--
-- Name: swh_mktemp_dir_entry(regclass); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_dir_entry(tblname regclass) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    execute format('
	create temporary table tmp_%I
	    (like %I including defaults, dir_id sha1_git)
	    on commit drop;
        alter table tmp_%I drop column id;
	', tblname, tblname, tblname, tblname);
    return;
end
$$;


--
-- Name: swh_mktemp_release(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_release() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    create temporary table tmp_release (
        like release including defaults,
        author_name text not null default '',
        author_email text not null default ''
    ) on commit drop;
    alter table tmp_release drop column author;
    return;
end
$$;


--
-- Name: swh_mktemp_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_revision() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    create temporary table tmp_revision (
        like revision including defaults,
        author_name text not null default '',
        author_email text not null default '',
        committer_name text not null default '',
        committer_email text not null default ''
    ) on commit drop;
    alter table tmp_revision drop column author;
    alter table tmp_revision drop column committer;
    return;
end
$$;


--
-- Name: swh_person_add_from_release(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_person_add_from_release() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    with t as (
        select distinct author_name as name, author_email as email from tmp_release
    ) insert into person (name, email)
    select name, email from t
    where not exists (
        select 1
	from person p
	where t.name = p.name and t.email = p.email
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
        select author_name as name, author_email as email from tmp_revision
    union
        select committer_name as name, committer_email as email from tmp_revision
    ) insert into person (name, email)
    select distinct name, email from t
    where not exists (
        select 1
	from person p
	where t.name = p.name and t.email = p.email
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

    insert into release (id, revision, date, date_offset, name, comment, author)
    select t.id, t.revision, t.date, t.date_offset, t.name, t.comment, a.id
    from tmp_release t
    left join person a on a.name = t.author_name and a.email = t.author_email;
    return;
end
$$;


--
-- Name: swh_release_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_release_missing() RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select id from tmp_release
	except
	select id from release;
    return;
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

    insert into revision (id, date, date_offset, committer_date, committer_date_offset, type, directory, message, author, committer)
    select t.id, t.date, t.date_offset, t.committer_date, t.committer_date_offset, t.type, t.directory, t.message, a.id, c.id
    from tmp_revision t
    left join person a on a.name = t.author_name and a.email = t.author_email
    left join person c on c.name = t.committer_name and c.email = t.committer_email;
    return;
end
$$;


--
-- Name: occurrence; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE occurrence (
    origin bigint NOT NULL,
    branch text NOT NULL,
    revision sha1_git NOT NULL
);


--
-- Name: swh_revision_find_occurrence(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_find_occurrence(revision_id sha1_git) RETURNS occurrence
    LANGUAGE plpgsql
    AS $$
declare
    occ occurrence%ROWTYPE;
    rev sha1_git;
begin
    -- first check to see if revision_id is already pointed by an occurrence
    select origin, branch, revision
    from occurrence_history as occ_hist
    where occ_hist.revision = revision_id
    order by upper(occ_hist.validity)  -- TODO filter by authority?
    limit 1
    into occ;

    -- no occurrence point to revision_id, walk up the history
    if not found then
        -- recursively walk the history, stopping immediately before a revision
        -- pointed to by an occurrence.
	-- TODO find a nicer way to stop at, but *including*, that revision
	with recursive revlog as (
	    (select revision_id as rev_id, 0 as depth)
	    union all
	    (select hist.parent_id as rev_id, revlog.depth + 1
	     from revlog
	     join revision_history as hist on hist.id = revlog.rev_id
	     and not exists(select 1 from occurrence_history
			    where revision = hist.parent_id)
	     limit 1)
	)
	select rev_id from revlog order by depth desc limit 1
	into strict rev;

	-- as we stopped before a pointed by revision, look it up again and
	-- return its data
	select origin, branch, revision
	from revision_history as rev_hist, occurrence_history as occ_hist
	where rev_hist.id = rev
	and occ_hist.revision = rev_hist.parent_id
	order by upper(occ_hist.validity)  -- TODO filter by authority?
	limit 1
	into strict occ;  -- will fail if no occurrence is found, and that's OK
    end if;

    return occ;
end
$$;


--
-- Name: swh_revision_list(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_list(root_revision sha1_git) RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
begin
    return query
	with recursive rev_list(id) as (
	    (select id from revision where id = root_revision)
	    union
	    (select parent_id
	     from revision_history as h
	     join rev_list on h.id = rev_list.id)
	)
	select * from rev_list;
    return;
end
$$;


--
-- Name: swh_revision_log(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_log(root_revision sha1_git) RETURNS SETOF revision_log_entry
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select revision.id, date, date_offset,
	    committer_date, committer_date_offset,
	    type, directory, message,
	    author.name as author_name, author.email as author_email,
	    committer.name as committer_name, committer.email as committer_email
	from swh_revision_list(root_revision) as rev_list
	join revision on revision.id = rev_list
	join person as author on revision.author = author.id
	join person as committer on revision.committer = committer.id;
    return;
end
$$;


--
-- Name: swh_revision_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_missing() RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select id from tmp_revision
	except
	select id from revision;
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
	select sha1, sha1_git, sha256 from tmp_skipped_content
	where not exists
	(select 1 from skipped_content s where
	    sha1 is not distinct from s.sha1 and
	    sha1_git is not distinct from s.sha1_git and
	    sha256 is not distinct from s.sha256);
    return;
end
$$;


--
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE dbversion (
    version integer NOT NULL,
    release timestamp with time zone,
    description text
);


--
-- Name: directory; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory (
    id sha1_git NOT NULL,
    dir_entries bigint[],
    file_entries bigint[],
    rev_entries bigint[]
);


--
-- Name: directory_entry_dir; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory_entry_dir (
    id bigint NOT NULL,
    target sha1_git,
    name unix_path,
    perms file_perms,
    atime timestamp with time zone,
    mtime timestamp with time zone,
    ctime timestamp with time zone
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
-- Name: directory_entry_file; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory_entry_file (
    id bigint NOT NULL,
    target sha1_git,
    name unix_path,
    perms file_perms,
    atime timestamp with time zone,
    mtime timestamp with time zone,
    ctime timestamp with time zone
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
-- Name: directory_entry_rev; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory_entry_rev (
    id bigint NOT NULL,
    target sha1_git,
    name unix_path,
    perms file_perms,
    atime timestamp with time zone,
    mtime timestamp with time zone,
    ctime timestamp with time zone
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
-- Name: fetch_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE fetch_history (
    id bigint NOT NULL,
    origin bigint,
    date timestamp with time zone NOT NULL,
    status boolean,
    result json,
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
-- Name: list_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE list_history (
    id bigint NOT NULL,
    organization bigint,
    date timestamp with time zone NOT NULL,
    status boolean,
    result json,
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
-- Name: occurrence_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE occurrence_history (
    origin bigint NOT NULL,
    branch text NOT NULL,
    revision sha1_git NOT NULL,
    authority bigint NOT NULL,
    validity tstzrange NOT NULL
);


--
-- Name: organization; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE organization (
    id bigint NOT NULL,
    parent_id bigint,
    name text NOT NULL,
    description text,
    homepage text,
    list_engine text,
    list_url text,
    list_params json,
    latest_list timestamp with time zone
);


--
-- Name: organization_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE organization_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE organization_id_seq OWNED BY organization.id;


--
-- Name: origin; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE origin (
    id bigint NOT NULL,
    type text,
    url text NOT NULL
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
-- Name: person; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE person (
    id bigint NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    email text DEFAULT ''::text NOT NULL
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
-- Name: project; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE project (
    id bigint NOT NULL,
    organization bigint,
    origin bigint,
    name text,
    description text,
    homepage text,
    doap jsonb
);


--
-- Name: project_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE project_history (
    id bigint NOT NULL,
    project bigint,
    validity tstzrange,
    organization bigint,
    origin bigint,
    name text,
    description text,
    homepage text,
    doap jsonb
);


--
-- Name: project_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE project_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE project_history_id_seq OWNED BY project_history.id;


--
-- Name: project_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE project_id_seq OWNED BY project.id;


--
-- Name: release; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE release (
    id sha1_git NOT NULL,
    revision sha1_git,
    date timestamp with time zone,
    date_offset smallint,
    name text,
    comment bytea,
    author bigint
);


--
-- Name: revision; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE revision (
    id sha1_git NOT NULL,
    date timestamp with time zone,
    date_offset smallint,
    committer_date timestamp with time zone,
    committer_date_offset smallint,
    type revision_type NOT NULL,
    directory sha1_git,
    message bytea,
    author bigint,
    committer bigint
);


--
-- Name: revision_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE revision_history (
    id sha1_git NOT NULL,
    parent_id sha1_git,
    parent_rank integer DEFAULT 0 NOT NULL
);


--
-- Name: skipped_content; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE skipped_content (
    sha1 sha1,
    sha1_git sha1_git,
    sha256 sha256,
    length bigint NOT NULL,
    ctime timestamp with time zone DEFAULT now() NOT NULL,
    status content_status DEFAULT 'absent'::content_status NOT NULL,
    reason text NOT NULL,
    origin bigint
);


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

ALTER TABLE ONLY fetch_history ALTER COLUMN id SET DEFAULT nextval('fetch_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history ALTER COLUMN id SET DEFAULT nextval('list_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization ALTER COLUMN id SET DEFAULT nextval('organization_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin ALTER COLUMN id SET DEFAULT nextval('origin_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person ALTER COLUMN id SET DEFAULT nextval('person_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY project ALTER COLUMN id SET DEFAULT nextval('project_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_history ALTER COLUMN id SET DEFAULT nextval('project_history_id_seq'::regclass);


--
-- Data for Name: content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content (sha1, sha1_git, sha256, length, ctime, status) FROM stdin;
\.


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
17	2015-09-30 11:01:56.89576+02	Work In Progress
\.


--
-- Data for Name: directory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory (id, dir_entries, file_entries, rev_entries) FROM stdin;
\.


--
-- Data for Name: directory_entry_dir; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_entry_dir (id, target, name, perms, atime, mtime, ctime) FROM stdin;
\.


--
-- Name: directory_entry_dir_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('directory_entry_dir_id_seq', 1, false);


--
-- Data for Name: directory_entry_file; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_entry_file (id, target, name, perms, atime, mtime, ctime) FROM stdin;
\.


--
-- Name: directory_entry_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('directory_entry_file_id_seq', 1, false);


--
-- Data for Name: directory_entry_rev; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_entry_rev (id, target, name, perms, atime, mtime, ctime) FROM stdin;
\.


--
-- Name: directory_entry_rev_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('directory_entry_rev_id_seq', 1, false);


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

COPY list_history (id, organization, date, status, result, stdout, stderr, duration) FROM stdin;
\.


--
-- Name: list_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('list_history_id_seq', 1, false);


--
-- Data for Name: occurrence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY occurrence (origin, branch, revision) FROM stdin;
\.


--
-- Data for Name: occurrence_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY occurrence_history (origin, branch, revision, authority, validity) FROM stdin;
\.


--
-- Data for Name: organization; Type: TABLE DATA; Schema: public; Owner: -
--

COPY organization (id, parent_id, name, description, homepage, list_engine, list_url, list_params, latest_list) FROM stdin;
1	\N	softwareheritage	Software Heritage	http://www.softwareheritage.org	\N	\N	\N	\N
\.


--
-- Name: organization_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('organization_id_seq', 1, true);


--
-- Data for Name: origin; Type: TABLE DATA; Schema: public; Owner: -
--

COPY origin (id, type, url) FROM stdin;
\.


--
-- Name: origin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('origin_id_seq', 1, false);


--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: -
--

COPY person (id, name, email) FROM stdin;
\.


--
-- Name: person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('person_id_seq', 1, false);


--
-- Data for Name: project; Type: TABLE DATA; Schema: public; Owner: -
--

COPY project (id, organization, origin, name, description, homepage, doap) FROM stdin;
\.


--
-- Data for Name: project_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY project_history (id, project, validity, organization, origin, name, description, homepage, doap) FROM stdin;
\.


--
-- Name: project_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('project_history_id_seq', 1, false);


--
-- Name: project_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('project_id_seq', 1, false);


--
-- Data for Name: release; Type: TABLE DATA; Schema: public; Owner: -
--

COPY release (id, revision, date, date_offset, name, comment, author) FROM stdin;
\.


--
-- Data for Name: revision; Type: TABLE DATA; Schema: public; Owner: -
--

COPY revision (id, date, date_offset, committer_date, committer_date_offset, type, directory, message, author, committer) FROM stdin;
\.


--
-- Data for Name: revision_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY revision_history (id, parent_id, parent_rank) FROM stdin;
\.


--
-- Data for Name: skipped_content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY skipped_content (sha1, sha1_git, sha256, length, ctime, status, reason, origin) FROM stdin;
\.


--
-- Name: content_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY content
    ADD CONSTRAINT content_pkey PRIMARY KEY (sha1);


--
-- Name: dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: directory_entry_dir_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY directory_entry_dir
    ADD CONSTRAINT directory_entry_dir_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY directory_entry_file
    ADD CONSTRAINT directory_entry_file_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_rev_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY directory_entry_rev
    ADD CONSTRAINT directory_entry_rev_pkey PRIMARY KEY (id);


--
-- Name: directory_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY directory
    ADD CONSTRAINT directory_pkey PRIMARY KEY (id);


--
-- Name: fetch_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY fetch_history
    ADD CONSTRAINT fetch_history_pkey PRIMARY KEY (id);


--
-- Name: list_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY list_history
    ADD CONSTRAINT list_history_pkey PRIMARY KEY (id);


--
-- Name: occurrence_history_origin_branch_revision_authority_validi_excl; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_origin_branch_revision_authority_validi_excl EXCLUDE USING gist (origin WITH =, branch WITH =, revision WITH =, authority WITH =, validity WITH &&);


--
-- Name: occurrence_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_pkey PRIMARY KEY (origin, branch, revision, authority, validity);


--
-- Name: occurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY occurrence
    ADD CONSTRAINT occurrence_pkey PRIMARY KEY (origin, branch, revision);


--
-- Name: organization_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- Name: origin_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY origin
    ADD CONSTRAINT origin_pkey PRIMARY KEY (id);


--
-- Name: person_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: project_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project_history
    ADD CONSTRAINT project_history_pkey PRIMARY KEY (id);


--
-- Name: project_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_pkey PRIMARY KEY (id);


--
-- Name: release_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_pkey PRIMARY KEY (id);


--
-- Name: revision_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY revision_history
    ADD CONSTRAINT revision_history_pkey PRIMARY KEY (id, parent_rank);


--
-- Name: revision_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY revision
    ADD CONSTRAINT revision_pkey PRIMARY KEY (id);


--
-- Name: skipped_content_sha1_sha1_git_sha256_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY skipped_content
    ADD CONSTRAINT skipped_content_sha1_sha1_git_sha256_key UNIQUE (sha1, sha1_git, sha256);


--
-- Name: content_sha1_git_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX content_sha1_git_idx ON content USING btree (sha1_git);


--
-- Name: content_sha256_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX content_sha256_idx ON content USING btree (sha256);


--
-- Name: directory_dir_entries_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX directory_dir_entries_idx ON directory USING gin (dir_entries);


--
-- Name: directory_entry_dir_target_name_perms_atime_mtime_ctime_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_dir_target_name_perms_atime_mtime_ctime_idx ON directory_entry_dir USING btree (target, name, perms, atime, mtime, ctime);


--
-- Name: directory_entry_dir_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_dir_target_name_perms_idx ON directory_entry_dir USING btree (target, name, perms) WHERE (((atime IS NULL) AND (mtime IS NULL)) AND (ctime IS NULL));


--
-- Name: directory_entry_file_target_name_perms_atime_mtime_ctime_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_file_target_name_perms_atime_mtime_ctime_idx ON directory_entry_file USING btree (target, name, perms, atime, mtime, ctime);


--
-- Name: directory_entry_file_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_file_target_name_perms_idx ON directory_entry_file USING btree (target, name, perms) WHERE (((atime IS NULL) AND (mtime IS NULL)) AND (ctime IS NULL));


--
-- Name: directory_entry_rev_target_name_perms_atime_mtime_ctime_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_rev_target_name_perms_atime_mtime_ctime_idx ON directory_entry_rev USING btree (target, name, perms, atime, mtime, ctime);


--
-- Name: directory_entry_rev_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_rev_target_name_perms_idx ON directory_entry_rev USING btree (target, name, perms) WHERE (((atime IS NULL) AND (mtime IS NULL)) AND (ctime IS NULL));


--
-- Name: directory_file_entries_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX directory_file_entries_idx ON directory USING gin (file_entries);


--
-- Name: directory_rev_entries_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX directory_rev_entries_idx ON directory USING gin (rev_entries);


--
-- Name: person_name_email_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX person_name_email_idx ON person USING btree (name, email);


--
-- Name: skipped_content_sha1_git_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX skipped_content_sha1_git_idx ON skipped_content USING btree (sha1_git);


--
-- Name: skipped_content_sha1_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX skipped_content_sha1_idx ON skipped_content USING btree (sha1);


--
-- Name: skipped_content_sha256_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX skipped_content_sha256_idx ON skipped_content USING btree (sha256);


--
-- Name: fetch_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY fetch_history
    ADD CONSTRAINT fetch_history_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: list_history_organization_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history
    ADD CONSTRAINT list_history_organization_fkey FOREIGN KEY (organization) REFERENCES organization(id);


--
-- Name: occurrence_history_authority_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_authority_fkey FOREIGN KEY (authority) REFERENCES organization(id);


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
-- Name: organization_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization
    ADD CONSTRAINT organization_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES organization(id);


--
-- Name: project_history_organization_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_history
    ADD CONSTRAINT project_history_organization_fkey FOREIGN KEY (organization) REFERENCES organization(id);


--
-- Name: project_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_history
    ADD CONSTRAINT project_history_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: project_history_project_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project_history
    ADD CONSTRAINT project_history_project_fkey FOREIGN KEY (project) REFERENCES project(id);


--
-- Name: project_organization_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_organization_fkey FOREIGN KEY (organization) REFERENCES organization(id);


--
-- Name: project_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


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

