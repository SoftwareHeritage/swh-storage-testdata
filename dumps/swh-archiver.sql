--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.3
-- Dumped by pg_dump version 9.5.3

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
-- Name: archive_id; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE archive_id AS ENUM (
    'banco'
);


--
-- Name: archive_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE archive_status AS ENUM (
    'missing',
    'ongoing',
    'present'
);


--
-- Name: TYPE archive_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE archive_status IS 'Status of a given archive';


--
-- Name: sha1; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha1 AS bytea
	CONSTRAINT sha1_check CHECK ((length(VALUE) = 20));


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE archive (
    id archive_id NOT NULL,
    url text
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
-- Name: COLUMN archive.url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN archive.url IS 'Url identifying the archiver api';


--
-- Name: content_archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_archive (
    content_id sha1 NOT NULL,
    archive_id archive_id NOT NULL,
    status archive_status,
    mtime timestamp with time zone
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
-- Name: COLUMN content_archive.archive_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive.archive_id IS 'content whereabouts';


--
-- Name: COLUMN content_archive.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive.status IS 'content status';


--
-- Name: COLUMN content_archive.mtime; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_archive.mtime IS 'last time the content was stored';


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

COPY archive (id, url) FROM stdin;
banco	http://banco.softwareheritage.org:5003/
\.


--
-- Data for Name: content_archive; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content_archive (content_id, archive_id, status, mtime) FROM stdin;
\.


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
1	2016-07-20 15:52:27.316087+02	Work In Progress
\.


--
-- Name: archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY archive
    ADD CONSTRAINT archive_pkey PRIMARY KEY (id);


--
-- Name: content_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_archive
    ADD CONSTRAINT content_archive_pkey PRIMARY KEY (content_id, archive_id);


--
-- Name: dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: content_archive_archive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_archive
    ADD CONSTRAINT content_archive_archive_id_fkey FOREIGN KEY (archive_id) REFERENCES archive(id);


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

