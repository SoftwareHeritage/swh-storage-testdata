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
	perms file_perms
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
	lister uuid,
	lister_metadata jsonb,
	doap jsonb,
	last_seen timestamp with time zone,
	last_id bigint
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
-- Name: revision_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE revision_entry AS (
	id sha1_git,
	date timestamp with time zone,
	date_offset smallint,
	committer_date timestamp with time zone,
	committer_date_offset smallint,
	type revision_type,
	directory sha1_git,
	message bytea,
	author_name bytea,
	author_email bytea,
	committer_name bytea,
	committer_email bytea,
	metadata jsonb,
	synthetic boolean,
	parents bytea[]
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
	author_name bytea,
	author_email bytea,
	committer_name bytea,
	committer_email bytea,
	metadata jsonb,
	synthetic boolean
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

    select origin.type, origin.url, occ.branch, rev, dir.path
    from origin
    where origin.id = occ.origin
    into coc;

    return coc;  -- might be NULL
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
        select dir_id, type, target, name, perms
        from swh_directory_walk_one(walked_dir_id)
        union all
        select dir_id, type, target, (dirname || '/' || name)::unix_path as name, perms
        from (select (swh_directory_walk_one(dirs.target)).*, dirs.name as dirname
              from (select target, name from entries where type = 'dir') as dirs) as with_parent
    )
    select dir_id, type, target, name, perms
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
	    target, name, perms
     from ls_d
     left join directory_entry_dir d on ls_d.entry_id = d.id)
    union
    (select dir_id, 'file'::directory_entry_type as type,
	    target, name, perms
     from ls_f
     left join directory_entry_file d on ls_f.entry_id = d.id)
    union
    (select dir_id, 'rev'::directory_entry_type as type,
	    target, name, perms
     from ls_r
     left join directory_entry_rev d on ls_r.entry_id = d.id)
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
    on t.lister = e.lister AND e.lister_metadata @> t.lister_metadata;
  return;
end
$$;


--
-- Name: swh_entity_history_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_entity_history_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into entity_history (
        uuid, parent, name, type, description, homepage, active, generated,
	lister, lister_metadata, doap, validity
    ) select * from tmp_entity_history;
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
-- Name: swh_mktemp_entity_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_entity_history() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_entity_history (
        like entity_history including defaults);
    alter table tmp_entity_history drop column id;
$$;


--
-- Name: swh_mktemp_entity_lister(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_entity_lister() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_entity_lister (
        id bigint,
        lister uuid,
	lister_metadata jsonb
    );
$$;


--
-- Name: swh_mktemp_release(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_release() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_release (
        like release including defaults,
        author_name bytea not null default '',
        author_email bytea not null default ''
    ) on commit drop;
    alter table tmp_release drop column author;
$$;


--
-- Name: swh_mktemp_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_revision() RETURNS void
    LANGUAGE sql
    AS $$
    create temporary table tmp_revision (
        like revision including defaults,
        author_name bytea not null default '',
        author_email bytea not null default '',
        committer_name bytea not null default '',
        committer_email bytea not null default ''
    ) on commit drop;
    alter table tmp_revision drop column author;
    alter table tmp_revision drop column committer;
$$;


--
-- Name: swh_occurrence_history_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_occurrence_history_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    -- Update intervals we have the data to update
    with new_intervals as (
        select t.origin, t.branch, t.authority, t.validity,
	       o.validity - t.validity as new_validity
	from tmp_occurrence_history t
        left join occurrence_history o
        using (origin, branch, authority)
	where o.origin is not null),
    -- do not update intervals if they would become empty (perfect overlap)
    to_update as (
        select * from new_intervals
	where not isempty(new_validity))
    update occurrence_history o set validity = t.new_validity
    from to_update t
    where o.origin = t.origin and o.branch = t.branch and o.authority = t.authority;

    -- Now only insert intervals that aren't already present
    insert into occurrence_history (origin, branch, revision, authority, validity)
	select distinct origin, branch, revision, authority, validity
	from tmp_occurrence_history t
	where not exists (
	    select 1 from occurrence_history o
	    where o.origin = t.origin and o.branch = t.branch and
	          o.authority = t.authority and o.revision = t.revision and
		  o.validity = t.validity);
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

    insert into release (id, revision, date, date_offset, name, comment, author, synthetic)
    select t.id, t.revision, t.date, t.date_offset, t.name, t.comment, a.id, t.synthetic
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
        select id from tmp_release t
	where not exists (
	select 1 from release r
	where r.id = t.id);
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

    insert into revision (id, date, date_offset, committer_date, committer_date_offset, type, directory, message, author, committer, metadata, synthetic)
    select t.id, t.date, t.date_offset, t.committer_date, t.committer_date_offset, t.type, t.directory, t.message, a.id, c.id, t.metadata, t.synthetic
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
    LANGUAGE sql STABLE
    AS $$
	select origin, branch, revision
	from swh_revision_list_children(revision_id) as rev_list(sha1_git)
	left join occurrence_history occ_hist
	on rev_list.sha1_git = occ_hist.revision
	where occ_hist.origin is not null
	order by upper(occ_hist.validity)  -- TODO filter by authority?
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
        select t.id, r.date, r.date_offset,
               r.committer_date, r.committer_date_offset,
               r.type, r.directory, r.message,
               a.name, a.email, c.name, c.email, r.metadata, r.synthetic,
	       array_agg(rh.parent_id::bytea order by rh.parent_rank)
                   as parents
        from tmp_revision t
        left join revision r on t.id = r.id
        left join person a on a.id = r.author
        left join person c on c.id = r.committer
        left join revision_history rh on rh.id = r.id
        group by t.id, a.name, a.email, r.date, r.date_offset,
               c.name, c.email, r.committer_date, r.committer_date_offset,
               r.type, r.directory, r.message, r.metadata, r.synthetic;
    return;
end
$$;


--
-- Name: swh_revision_list(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_list(root_revision sha1_git) RETURNS SETOF sha1_git
    LANGUAGE sql STABLE
    AS $$
    with recursive rev_list(id) as (
	(select id from revision where id = root_revision)
	union
	(select parent_id
	 from revision_history as h
	 join rev_list on h.id = rev_list.id)
    )
    select * from rev_list;
$$;


--
-- Name: swh_revision_list_children(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_list_children(root_revision sha1_git) RETURNS SETOF sha1_git
    LANGUAGE sql STABLE
    AS $$
    with recursive rev_list(id) as (
	(select id from revision where id = root_revision)
	union
	(select h.id
	 from revision_history as h
	 join rev_list on h.parent_id = rev_list.id)
    )
    select * from rev_list;
$$;


--
-- Name: swh_revision_log(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_log(root_revision sha1_git) RETURNS SETOF revision_log_entry
    LANGUAGE sql STABLE
    AS $$
    select revision.id, date, date_offset,
	committer_date, committer_date_offset,
	type, directory, message,
	author.name as author_name, author.email as author_email,
	committer.name as committer_name, committer.email as committer_email,
        revision.metadata, revision.synthetic
    from swh_revision_list(root_revision) as rev_list
    join revision on revision.id = rev_list
    join person as author on revision.author = author.id
    join person as committer on revision.committer = committer.id;
$$;


--
-- Name: swh_revision_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_missing() RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select id from tmp_revision t
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
    with all_entities as (
      select uuid, parent, name, type, description, homepage, active,
             generated, lister, lister_metadata, doap, last_seen, last_id
      from (
          select row_number() over (partition by uuid order by unnest(validity) desc) as row,
	         id as last_id, uuid, parent, name, type, description, homepage, active,
		 generated, lister, lister_metadata, doap,
	         unnest(validity) as last_seen
          from entity_history
      ) as latest_entities
      where latest_entities.row = 1
    ),
    updated_uuids as (
      update entity set
        parent = all_entities.parent,
        name = all_entities.name,
	type = all_entities.type,
	description = all_entities.description,
	homepage = all_entities.homepage,
	active = all_entities.active,
	generated = all_entities.generated,
	lister = all_entities.lister,
	lister_metadata = all_entities.lister_metadata,
	doap = all_entities.doap,
	last_seen = all_entities.last_seen,
        last_id = all_entities.last_id
      from all_entities
      where entity.uuid = all_entities.uuid
      returning entity.uuid
    )
    insert into entity
    (select * from all_entities
     where uuid not in (select uuid from updated_uuids));
    return null;
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
-- Name: directory_entry_file; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
-- Name: directory_entry_rev; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
-- Name: entity; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    lister uuid,
    lister_metadata jsonb,
    doap jsonb,
    last_seen timestamp with time zone,
    last_id bigint
);


--
-- Name: entity_equivalence; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE entity_equivalence (
    entity1 uuid NOT NULL,
    entity2 uuid NOT NULL,
    CONSTRAINT order_entities CHECK ((entity1 < entity2))
);


--
-- Name: entity_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    lister uuid,
    lister_metadata jsonb,
    doap jsonb,
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
    entity uuid,
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
-- Name: listable_entity; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE listable_entity (
    uuid uuid NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    list_engine text,
    list_url text,
    list_params json,
    latest_list timestamp with time zone
);


--
-- Name: occurrence_history; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE occurrence_history (
    origin bigint NOT NULL,
    branch text NOT NULL,
    revision sha1_git NOT NULL,
    authority uuid NOT NULL,
    validity tstzrange NOT NULL
);


--
-- Name: origin; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
-- Name: person; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE person (
    id bigint NOT NULL,
    name bytea DEFAULT '\x'::bytea NOT NULL,
    email bytea DEFAULT '\x'::bytea NOT NULL
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
-- Name: release; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE release (
    id sha1_git NOT NULL,
    revision sha1_git,
    date timestamp with time zone,
    date_offset smallint,
    name text,
    comment bytea,
    author bigint,
    synthetic boolean DEFAULT false NOT NULL
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
    committer bigint,
    metadata jsonb,
    synthetic boolean DEFAULT false NOT NULL
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
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin ALTER COLUMN id SET DEFAULT nextval('origin_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person ALTER COLUMN id SET DEFAULT nextval('person_id_seq'::regclass);


--
-- Data for Name: content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content (sha1, sha1_git, sha256, length, ctime, status) FROM stdin;
\.


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
30	2015-11-03 16:43:47.526352+01	Work In Progress
\.


--
-- Data for Name: directory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory (id, dir_entries, file_entries, rev_entries) FROM stdin;
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
-- Data for Name: entity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY entity (uuid, parent, name, type, description, homepage, active, generated, lister, lister_metadata, doap, last_seen, last_id) FROM stdin;
34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	8
4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	4
4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	6
5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	5
5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	1
6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	2
7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	3
9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	10
ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	11
aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	7
e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	\N	2015-11-03 16:43:47.526352+01	9
\.


--
-- Data for Name: entity_equivalence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY entity_equivalence (entity1, entity2) FROM stdin;
\.


--
-- Data for Name: entity_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY entity_history (id, uuid, parent, name, type, description, homepage, active, generated, lister, lister_metadata, doap, validity) FROM stdin;
1	5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
2	6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
3	7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
4	4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
5	5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
6	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
8	34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
9	e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
10	9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
11	ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	\N	{"2015-11-03 16:43:47.526352+01"}
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

COPY occurrence (origin, branch, revision) FROM stdin;
\.


--
-- Data for Name: occurrence_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY occurrence_history (origin, branch, revision, authority, validity) FROM stdin;
\.


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
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: -
--

COPY person (id, name, email) FROM stdin;
\.


--
-- Name: person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('person_id_seq', 1, false);


--
-- Data for Name: release; Type: TABLE DATA; Schema: public; Owner: -
--

COPY release (id, revision, date, date_offset, name, comment, author, synthetic) FROM stdin;
\.


--
-- Data for Name: revision; Type: TABLE DATA; Schema: public; Owner: -
--

COPY revision (id, date, date_offset, committer_date, committer_date_offset, type, directory, message, author, committer, metadata, synthetic) FROM stdin;
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
-- Name: entity_equivalence_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY entity_equivalence
    ADD CONSTRAINT entity_equivalence_pkey PRIMARY KEY (entity1, entity2);


--
-- Name: entity_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY entity_history
    ADD CONSTRAINT entity_history_pkey PRIMARY KEY (id);


--
-- Name: entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (uuid);


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
-- Name: listable_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY listable_entity
    ADD CONSTRAINT listable_entity_pkey PRIMARY KEY (uuid);


--
-- Name: occurrence_history_origin_branch_revision_authority_validi_excl; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_origin_branch_revision_authority_validi_excl EXCLUDE USING gist (origin WITH =, branch WITH =, revision WITH =, ((authority)::text) WITH =, validity WITH &&);


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
-- Name: content_ctime_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX content_ctime_idx ON content USING btree (ctime);


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
-- Name: directory_entry_dir_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_dir_target_name_perms_idx ON directory_entry_dir USING btree (target, name, perms);


--
-- Name: directory_entry_file_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_file_target_name_perms_idx ON directory_entry_file USING btree (target, name, perms);


--
-- Name: directory_entry_rev_target_name_perms_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX directory_entry_rev_target_name_perms_idx ON directory_entry_rev USING btree (target, name, perms);


--
-- Name: directory_file_entries_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX directory_file_entries_idx ON directory USING gin (file_entries);


--
-- Name: directory_rev_entries_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX directory_rev_entries_idx ON directory USING gin (rev_entries);


--
-- Name: entity_history_name_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX entity_history_name_idx ON entity_history USING btree (name);


--
-- Name: entity_history_uuid_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX entity_history_uuid_idx ON entity_history USING btree (uuid);


--
-- Name: entity_name_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX entity_name_idx ON entity USING btree (name);


--
-- Name: occurrence_history_revision_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX occurrence_history_revision_idx ON occurrence_history USING btree (revision);


--
-- Name: person_name_email_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX person_name_email_idx ON person USING btree (name, email);


--
-- Name: release_revision_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX release_revision_idx ON release USING btree (revision);


--
-- Name: revision_directory_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX revision_directory_idx ON revision USING btree (directory);


--
-- Name: revision_history_parent_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX revision_history_parent_id_idx ON revision_history USING btree (parent_id);


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
-- Name: update_entity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_entity AFTER INSERT OR DELETE OR UPDATE OR TRUNCATE ON entity_history FOR EACH STATEMENT EXECUTE PROCEDURE swh_update_entity_from_entity_history();


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
-- Name: entity_lister_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_lister_fkey FOREIGN KEY (lister) REFERENCES listable_entity(uuid);


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
-- Name: occurrence_history_authority_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_authority_fkey FOREIGN KEY (authority) REFERENCES entity(uuid);


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

