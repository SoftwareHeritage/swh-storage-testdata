--
-- PostgreSQL database dump
--

-- Dumped from database version 10.5 (Debian 10.5-1.pgdg+1)
-- Dumped by pg_dump version 10.5 (Debian 10.5-1.pgdg+1)

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
-- Name: archive_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.archive_status AS ENUM (
    'missing',
    'ongoing',
    'present',
    'corrupted'
);


--
-- Name: TYPE archive_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.archive_status IS 'Status of a given copy of a content';


--
-- Name: bucket; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.bucket AS bytea
	CONSTRAINT bucket_check CHECK ((length(VALUE) = 2));


--
-- Name: sha1; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.sha1 AS bytea
	CONSTRAINT sha1_check CHECK ((length(VALUE) = 20));


--
-- Name: swh_content_copies_from_temp(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_content_copies_from_temp(archive_names text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
  begin
    with existing_content_ids as (
        select id
        from content
        inner join tmp_content on content.sha1 = tmp.sha1
    ), created_content_ids as (
        insert into content (sha1)
        select sha1 from tmp_content
        on conflict do nothing
        returning id
    ), content_ids as (
        select * from existing_content_ids
        union all
        select * from created_content_ids
    ), archive_ids as (
        select id from archive
        where name = any(archive_names)
    ) insert into content_copies (content_id, archive_id, mtime, status)
    select content_ids.id, archive_ids.id, now(), 'present'
    from content_ids cross join archive_ids
    on conflict (content_id, archive_id) do update
      set mtime = excluded.mtime, status = excluded.status;
  end
$$;


--
-- Name: swh_mktemp_content(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.swh_mktemp_content() RETURNS void
    LANGUAGE plpgsql
    AS $$
  begin
    create temporary table tmp_content (
        sha1 sha1 not null
    ) on commit drop;
    return;
  end
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.archive (
    id bigint NOT NULL,
    name text NOT NULL
);


--
-- Name: TABLE archive; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.archive IS 'The archives in which contents are stored';


--
-- Name: COLUMN archive.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.archive.id IS 'Short identifier for archives';


--
-- Name: COLUMN archive.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.archive.name IS 'Name of the archive';


--
-- Name: archive_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.archive_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: archive_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.archive_id_seq OWNED BY public.archive.id;


--
-- Name: content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content (
    id bigint NOT NULL,
    sha1 public.sha1 NOT NULL
);


--
-- Name: TABLE content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.content IS 'All the contents being archived by Software Heritage';


--
-- Name: COLUMN content.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.content.id IS 'Short id for the content being archived';


--
-- Name: COLUMN content.sha1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.content.sha1 IS 'SHA1 hash of the content being archived';


--
-- Name: content_copies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_copies (
    content_id bigint NOT NULL,
    archive_id bigint NOT NULL,
    mtime timestamp with time zone,
    status public.archive_status NOT NULL
);


--
-- Name: TABLE content_copies; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.content_copies IS 'Tracking of all content copies in the archives';


--
-- Name: COLUMN content_copies.mtime; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.content_copies.mtime IS 'Last update time of the copy';


--
-- Name: COLUMN content_copies.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.content_copies.status IS 'Status of the copy';


--
-- Name: content_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_id_seq OWNED BY public.content.id;


--
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dbversion (
    version integer NOT NULL,
    release timestamp with time zone,
    description text
);


--
-- Name: TABLE dbversion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.dbversion IS 'Schema update tracking';


--
-- Name: archive id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archive ALTER COLUMN id SET DEFAULT nextval('public.archive_id_seq'::regclass);


--
-- Name: content id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content ALTER COLUMN id SET DEFAULT nextval('public.content_id_seq'::regclass);


--
-- Data for Name: archive; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.archive (id, name) FROM stdin;
1	uffizi
2	banco
3	azure
\.


--
-- Data for Name: content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.content (id, sha1) FROM stdin;
\.


--
-- Data for Name: content_copies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.content_copies (content_id, archive_id, mtime, status) FROM stdin;
\.


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.dbversion (version, release, description) FROM stdin;
10	2018-10-16 12:20:28.698061+02	Work In Progress
\.


--
-- Name: archive_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.archive_id_seq', 3, true);


--
-- Name: content_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.content_id_seq', 1, false);


--
-- Name: archive archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archive
    ADD CONSTRAINT archive_pkey PRIMARY KEY (id);


--
-- Name: content_copies content_copies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_copies
    ADD CONSTRAINT content_copies_pkey PRIMARY KEY (content_id, archive_id);


--
-- Name: content content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content
    ADD CONSTRAINT content_pkey PRIMARY KEY (id);


--
-- Name: dbversion dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: archive_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX archive_name_idx ON public.archive USING btree (name);


--
-- Name: content_sha1_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX content_sha1_idx ON public.content USING btree (sha1);


--
-- PostgreSQL database dump complete
--

