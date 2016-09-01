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
-- Name: archive_id; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE archive_id AS ENUM (
    'uffizi',
    'banco'
);


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
-- Name: sha1; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN sha1 AS bytea
	CONSTRAINT sha1_check CHECK ((length(VALUE) = 20));


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

COPY content_archive (content_id, copies, num_present) FROM stdin;
\.


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
3	2016-09-01 11:23:45.125891+02	Work In Progress
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
    ADD CONSTRAINT content_archive_pkey PRIMARY KEY (content_id);


--
-- Name: dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: content_archive_num_present_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_archive_num_present_idx ON content_archive USING btree (num_present);


--
-- Name: update_num_present; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_num_present BEFORE INSERT OR UPDATE OF copies ON content_archive FOR EACH ROW EXECUTE PROCEDURE update_num_present();


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

