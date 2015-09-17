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
-- Name: sha1; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha1 AS bytea
	CONSTRAINT sha1_check CHECK ((length(VALUE) = 20));


--
-- Name: sha1_git; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha1_git AS bytea
	CONSTRAINT sha1_git_check CHECK ((length(VALUE) = 20));


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
-- Name: file_perms; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN file_perms AS integer;


--
-- Name: unix_path; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN unix_path AS text;


--
-- Name: directory_entry; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE directory_entry AS (
	dir_id sha1_git,
	type text,
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
-- Name: swh_content_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
    rows bigint;
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


--
-- Name: swh_content_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_missing() RETURNS SETOF content_signature
    LANGUAGE plpgsql
    AS $$
begin
    return query
	select sha1, sha1_git, sha256 from tmp_content
	except
	select sha1, sha1_git, sha256 from content;
    return;
end
$$;


--
-- Name: swh_directory_entry_dir_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_entry_dir_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into directory_entry_dir (target, name, perms, atime, mtime, ctime)
    select distinct t.target, t.name, t.perms, t.atime, t.mtime, t.ctime
    from tmp_directory_entry_dir t
    where not exists (
    select 1
    from directory_entry_dir i
    where t.target = i.target and t.name = i.name and t.perms = i.perms and
       t.atime is not distinct from i.atime and
       t.mtime is not distinct from i.mtime and
       t.ctime is not distinct from i.ctime);

    insert into directory_list_dir (entry_id, dir_id)
    select i.id, t.dir_id
    from tmp_directory_entry_dir t
    inner join directory_entry_dir i
    on t.target = i.target and t.name = i.name and t.perms = i.perms and
       t.atime is not distinct from i.atime and
       t.mtime is not distinct from i.mtime and
       t.ctime is not distinct from i.ctime;
    return;
end
$$;


--
-- Name: swh_directory_entry_file_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_entry_file_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into directory_entry_file (target, name, perms, atime, mtime, ctime)
    select distinct t.target, t.name, t.perms, t.atime, t.mtime, t.ctime
    from tmp_directory_entry_file t
    where not exists (
    select 1
    from directory_entry_file i
    where t.target = i.target and t.name = i.name and t.perms = i.perms and
       t.atime is not distinct from i.atime and
       t.mtime is not distinct from i.mtime and
       t.ctime is not distinct from i.ctime);

    insert into directory_list_file (entry_id, dir_id)
    select i.id, t.dir_id
    from tmp_directory_entry_file t
    inner join directory_entry_file i
    on t.target = i.target and t.name = i.name and t.perms = i.perms and
       t.atime is not distinct from i.atime and
       t.mtime is not distinct from i.mtime and
       t.ctime is not distinct from i.ctime;
    return;
end
$$;


--
-- Name: swh_directory_entry_rev_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_entry_rev_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    insert into directory_entry_rev (target, name, perms, atime, mtime, ctime)
    select distinct t.target, t.name, t.perms, t.atime, t.mtime, t.ctime
    from tmp_directory_entry_rev t
    where not exists (
    select 1
    from directory_entry_rev i
    where t.target = i.target and t.name = i.name and t.perms = i.perms and
       t.atime is not distinct from i.atime and
       t.mtime is not distinct from i.mtime and
       t.ctime is not distinct from i.ctime);

    insert into directory_list_rev (entry_id, dir_id)
    select i.id, t.dir_id
    from tmp_directory_entry_rev t
    inner join directory_entry_rev i
    on t.target = i.target and t.name = i.name and t.perms = i.perms and
       t.atime is not distinct from i.atime and
       t.mtime is not distinct from i.mtime and
       t.ctime is not distinct from i.ctime;
    return;
end
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: directory; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory (
    id sha1_git NOT NULL
);


--
-- Name: swh_directory_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_directory_missing() RETURNS SETOF directory
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
    return query (
        select dir_id, 'dir' as type, target, name, perms, atime, mtime, ctime
	from directory_list_dir l
	left join directory_entry_dir d
	on l.entry_id = d.id
	where l.dir_id = walked_dir_id
    union
        select dir_id, 'file' as type, target, name, perms, atime, mtime, ctime
	from directory_list_file l
	left join directory_entry_file d
	on l.entry_id = d.id
	where l.dir_id = walked_dir_id
    union
        select dir_id, 'rev' as type, target, name, perms, atime, mtime, ctime
	from directory_list_rev l
	left join directory_entry_rev d
	on l.entry_id = d.id
	where l.dir_id = walked_dir_id
    ) order by name;
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
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE dbversion (
    version integer NOT NULL,
    release timestamp with time zone,
    description text
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
-- Name: directory_list_dir; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory_list_dir (
    dir_id sha1_git NOT NULL,
    entry_id bigint NOT NULL
);


--
-- Name: directory_list_file; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory_list_file (
    dir_id sha1_git NOT NULL,
    entry_id bigint NOT NULL
);


--
-- Name: directory_list_rev; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE directory_list_rev (
    dir_id sha1_git NOT NULL,
    entry_id bigint NOT NULL
);


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
-- Name: occurrence; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE occurrence (
    origin bigint NOT NULL,
    branch text NOT NULL,
    revision sha1_git NOT NULL
);


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
14	2015-09-17 14:17:49.716919+02	Work In Progress
\.


--
-- Data for Name: directory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory (id) FROM stdin;
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
-- Data for Name: directory_list_dir; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_list_dir (dir_id, entry_id) FROM stdin;
\.


--
-- Data for Name: directory_list_file; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_list_file (dir_id, entry_id) FROM stdin;
\.


--
-- Data for Name: directory_list_rev; Type: TABLE DATA; Schema: public; Owner: -
--

COPY directory_list_rev (dir_id, entry_id) FROM stdin;
\.


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
-- Name: directory_list_dir_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY directory_list_dir
    ADD CONSTRAINT directory_list_dir_pkey PRIMARY KEY (dir_id, entry_id);


--
-- Name: directory_list_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY directory_list_file
    ADD CONSTRAINT directory_list_file_pkey PRIMARY KEY (dir_id, entry_id);


--
-- Name: directory_list_rev_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY directory_list_rev
    ADD CONSTRAINT directory_list_rev_pkey PRIMARY KEY (dir_id, entry_id);


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
-- Name: content_sha1_git_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX content_sha1_git_idx ON content USING btree (sha1_git);


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
-- Name: person_name_email_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX person_name_email_idx ON person USING btree (name, email);


--
-- Name: directory_list_dir_dir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_list_dir
    ADD CONSTRAINT directory_list_dir_dir_id_fkey FOREIGN KEY (dir_id) REFERENCES directory(id);


--
-- Name: directory_list_dir_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_list_dir
    ADD CONSTRAINT directory_list_dir_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES directory_entry_dir(id);


--
-- Name: directory_list_file_dir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_list_file
    ADD CONSTRAINT directory_list_file_dir_id_fkey FOREIGN KEY (dir_id) REFERENCES directory(id);


--
-- Name: directory_list_file_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_list_file
    ADD CONSTRAINT directory_list_file_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES directory_entry_file(id);


--
-- Name: directory_list_rev_dir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_list_rev
    ADD CONSTRAINT directory_list_rev_dir_id_fkey FOREIGN KEY (dir_id) REFERENCES directory(id);


--
-- Name: directory_list_rev_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_list_rev
    ADD CONSTRAINT directory_list_rev_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES directory_entry_rev(id);


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
-- Name: occurrence_history_revision_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_revision_fkey FOREIGN KEY (revision) REFERENCES revision(id);


--
-- Name: occurrence_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence
    ADD CONSTRAINT occurrence_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: occurrence_revision_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence
    ADD CONSTRAINT occurrence_revision_fkey FOREIGN KEY (revision) REFERENCES revision(id);


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
-- Name: release_revision_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_revision_fkey FOREIGN KEY (revision) REFERENCES revision(id);


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
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

