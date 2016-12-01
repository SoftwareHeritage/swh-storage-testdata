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
-- Name: cache_content_signature; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE cache_content_signature AS (
	sha1 sha1,
	sha1_git sha1_git,
	sha256 sha256,
	revision_paths bytea[]
);


--
-- Name: ctags_languages; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE ctags_languages AS ENUM (
    'Ada',
    'AnsiblePlaybook',
    'Ant',
    'Asm',
    'Asp',
    'Autoconf',
    'Automake',
    'Awk',
    'Basic',
    'BETA',
    'C',
    'C#',
    'C++',
    'Clojure',
    'Cobol',
    'CoffeeScript [disabled]',
    'CSS',
    'ctags',
    'D',
    'DBusIntrospect',
    'Diff',
    'DosBatch',
    'DTS',
    'Eiffel',
    'Erlang',
    'Falcon',
    'Flex',
    'Fortran',
    'gdbinit [disabled]',
    'Glade',
    'Go',
    'HTML',
    'Iniconf',
    'Java',
    'JavaProperties',
    'JavaScript',
    'JSON',
    'Lisp',
    'Lua',
    'M4',
    'Make',
    'man [disabled]',
    'MatLab',
    'Maven2',
    'Myrddin',
    'ObjectiveC',
    'OCaml',
    'OldC
  [disabled]',
    'OldC++ [disabled]',
    'Pascal',
    'Perl',
    'Perl6',
    'PHP',
    'PlistXML',
    'pod',
    'Protobuf',
    'Python',
    'PythonLoggingConfig',
    'R',
    'RelaxNG',
    'reStructuredText',
    'REXX',
    'RpmSpec',
    'Ruby',
    'Rust',
    'Scheme',
    'Sh',
    'SLang',
    'SML',
    'SQL',
    'SVG',
    'SystemdUnit',
    'SystemVerilog',
    'Tcl',
    'Tex',
    'TTCN',
    'Vera',
    'Verilog',
    'VHDL',
    'Vim',
    'WindRes',
    'XSLT',
    'YACC',
    'Yaml',
    'YumRepo',
    'Zephir'
);


--
-- Name: TYPE ctags_languages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE ctags_languages IS 'Languages recognized by ctags indexer';


--
-- Name: content_ctags_signature; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_ctags_signature AS (
	id sha1,
	name text,
	kind text,
	line bigint,
	lang ctags_languages
);


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
-- Name: content_fossology_license_signature; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_fossology_license_signature AS (
	id sha1,
	tool_name text,
	tool_version text,
	licenses text[]
);


--
-- Name: content_provenance; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE content_provenance AS (
	content sha1_git,
	revision sha1_git,
	origin bigint,
	visit bigint,
	path unix_path
);


--
-- Name: TYPE content_provenance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE content_provenance IS 'Provenance information on content';


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
-- Name: TYPE content_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE content_status IS 'Content visibility';


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
-- Name: TYPE entity_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE entity_type IS 'Entity types';


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
-- Name: languages; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE languages AS ENUM (
    'abap',
    'abnf',
    'actionscript',
    'actionscript-3',
    'ada',
    'adl',
    'agda',
    'alloy',
    'ambienttalk',
    'antlr',
    'antlr-with-actionscript-target',
    'antlr-with-c#-target',
    'antlr-with-cpp-target',
    'antlr-with-java-target',
    'antlr-with-objectivec-target',
    'antlr-with-perl-target',
    'antlr-with-python-target',
    'antlr-with-ruby-target',
    'apacheconf',
    'apl',
    'applescript',
    'arduino',
    'aspectj',
    'aspx-cs',
    'aspx-vb',
    'asymptote',
    'autohotkey',
    'autoit',
    'awk',
    'base-makefile',
    'bash',
    'bash-session',
    'batchfile',
    'bbcode',
    'bc',
    'befunge',
    'blitzbasic',
    'blitzmax',
    'bnf',
    'boo',
    'boogie',
    'brainfuck',
    'bro',
    'bugs',
    'c',
    'c#',
    'c++',
    'c-objdump',
    'ca65-assembler',
    'cadl',
    'camkes',
    'cbm-basic-v2',
    'ceylon',
    'cfengine3',
    'cfstatement',
    'chaiscript',
    'chapel',
    'cheetah',
    'cirru',
    'clay',
    'clojure',
    'clojurescript',
    'cmake',
    'cobol',
    'cobolfree',
    'coffeescript',
    'coldfusion-cfc',
    'coldfusion-html',
    'common-lisp',
    'component-pascal',
    'coq',
    'cpp-objdump',
    'cpsa',
    'crmsh',
    'croc',
    'cryptol',
    'csound-document',
    'csound-orchestra',
    'csound-score',
    'css',
    'css+django/jinja',
    'css+genshi-text',
    'css+lasso',
    'css+mako',
    'css+mozpreproc',
    'css+myghty',
    'css+php',
    'css+ruby',
    'css+smarty',
    'cuda',
    'cypher',
    'cython',
    'd',
    'd-objdump',
    'darcs-patch',
    'dart',
    'debian-control-file',
    'debian-sourcelist',
    'delphi',
    'dg',
    'diff',
    'django/jinja',
    'docker',
    'dtd',
    'duel',
    'dylan',
    'dylan-session',
    'dylanlid',
    'earl-grey',
    'easytrieve',
    'ebnf',
    'ec',
    'ecl',
    'eiffel',
    'elixir',
    'elixir-iex-session',
    'elm',
    'emacslisp',
    'embedded-ragel',
    'erb',
    'erlang',
    'erlang-erl-session',
    'evoque',
    'ezhil',
    'factor',
    'fancy',
    'fantom',
    'felix',
    'fish',
    'fortran',
    'fortranfixed',
    'foxpro',
    'fsharp',
    'gap',
    'gas',
    'genshi',
    'genshi-text',
    'gettext-catalog',
    'gherkin',
    'glsl',
    'gnuplot',
    'go',
    'golo',
    'gooddata-cl',
    'gosu',
    'gosu-template',
    'groff',
    'groovy',
    'haml',
    'handlebars',
    'haskell',
    'haxe',
    'hexdump',
    'html',
    'html+cheetah',
    'html+django/jinja',
    'html+evoque',
    'html+genshi',
    'html+handlebars',
    'html+lasso',
    'html+mako',
    'html+myghty',
    'html+php',
    'html+smarty',
    'html+twig',
    'html+velocity',
    'http',
    'hxml',
    'hy',
    'hybris',
    'idl',
    'idris',
    'igor',
    'inform-6',
    'inform-6-template',
    'inform-7',
    'ini',
    'io',
    'ioke',
    'irc-logs',
    'isabelle',
    'j',
    'jade',
    'jags',
    'jasmin',
    'java',
    'java-server-page',
    'javascript',
    'javascript+cheetah',
    'javascript+django/jinja',
    'javascript+genshi-text',
    'javascript+lasso',
    'javascript+mako',
    'javascript+mozpreproc',
    'javascript+myghty',
    'javascript+php',
    'javascript+ruby',
    'javascript+smarty',
    'jcl',
    'json',
    'json-ld',
    'julia',
    'julia-console',
    'kal',
    'kconfig',
    'koka',
    'kotlin',
    'lasso',
    'lean',
    'lesscss',
    'lighttpd-configuration-file',
    'limbo',
    'liquid',
    'literate-agda',
    'literate-cryptol',
    'literate-haskell',
    'literate-idris',
    'livescript',
    'llvm',
    'logos',
    'logtalk',
    'lsl',
    'lua',
    'makefile',
    'mako',
    'maql',
    'mask',
    'mason',
    'mathematica',
    'matlab',
    'matlab-session',
    'minid',
    'modelica',
    'modula-2',
    'moinmoin/trac-wiki-markup',
    'monkey',
    'moocode',
    'moonscript',
    'mozhashpreproc',
    'mozpercentpreproc',
    'mql',
    'mscgen',
    'msdos-session',
    'mupad',
    'mxml',
    'myghty',
    'mysql',
    'nasm',
    'nemerle',
    'nesc',
    'newlisp',
    'newspeak',
    'nginx-configuration-file',
    'nimrod',
    'nit',
    'nix',
    'nsis',
    'numpy',
    'objdump',
    'objdump-nasm',
    'objective-c',
    'objective-c++',
    'objective-j',
    'ocaml',
    'octave',
    'odin',
    'ooc',
    'opa',
    'openedge-abl',
    'pacmanconf',
    'pan',
    'parasail',
    'pawn',
    'perl',
    'perl6',
    'php',
    'pig',
    'pike',
    'pkgconfig',
    'pl/pgsql',
    'postgresql-console-(psql)',
    'postgresql-sql-dialect',
    'postscript',
    'povray',
    'powershell',
    'powershell-session',
    'praat',
    'prolog',
    'properties',
    'protocol-buffer',
    'puppet',
    'pypy-log',
    'python',
    'python-3',
    'python-3.0-traceback',
    'python-console-session',
    'python-traceback',
    'qbasic',
    'qml',
    'qvto',
    'racket',
    'ragel',
    'ragel-in-c-host',
    'ragel-in-cpp-host',
    'ragel-in-d-host',
    'ragel-in-java-host',
    'ragel-in-objective-c-host',
    'ragel-in-ruby-host',
    'raw-token-data',
    'rconsole',
    'rd',
    'rebol',
    'red',
    'redcode',
    'reg',
    'resourcebundle',
    'restructuredtext',
    'rexx',
    'rhtml',
    'roboconf-graph',
    'roboconf-instances',
    'robotframework',
    'rpmspec',
    'rql',
    'rsl',
    'ruby',
    'ruby-irb-session',
    'rust',
    's',
    'sass',
    'scala',
    'scalate-server-page',
    'scaml',
    'scheme',
    'scilab',
    'scss',
    'shen',
    'slim',
    'smali',
    'smalltalk',
    'smarty',
    'snobol',
    'sourcepawn',
    'sparql',
    'sql',
    'sqlite3con',
    'squidconf',
    'stan',
    'standard-ml',
    'supercollider',
    'swift',
    'swig',
    'systemverilog',
    'tads-3',
    'tap',
    'tcl',
    'tcsh',
    'tcsh-session',
    'tea',
    'termcap',
    'terminfo',
    'terraform',
    'tex',
    'text-only',
    'thrift',
    'todotxt',
    'trafficscript',
    'treetop',
    'turtle',
    'twig',
    'typescript',
    'urbiscript',
    'vala',
    'vb.net',
    'vctreestatus',
    'velocity',
    'verilog',
    'vgl',
    'vhdl',
    'viml',
    'x10',
    'xml',
    'xml+cheetah',
    'xml+django/jinja',
    'xml+evoque',
    'xml+lasso',
    'xml+mako',
    'xml+myghty',
    'xml+php',
    'xml+ruby',
    'xml+smarty',
    'xml+velocity',
    'xquery',
    'xslt',
    'xtend',
    'xul+mozpreproc',
    'yaml',
    'yaml+jinja',
    'zephir',
    'unknown'
);


--
-- Name: TYPE languages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE languages IS 'Languages recognized by language indexer';


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
-- Name: TYPE object_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE object_type IS 'Data object types stored in data model';


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
-- Name: TYPE revision_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE revision_type IS 'Possible revision types';


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
-- Name: swh_cache_content_get(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_cache_content_get(target sha1_git) RETURNS SETOF cache_content_signature
    LANGUAGE sql STABLE
    AS $$
    SELECT c.sha1, c.sha1_git, c.sha256, ccr.revision_paths
    FROM cache_content_revision ccr
    INNER JOIN content as c
    ON ccr.content = c.sha1_git
    where ccr.content = target
$$;


--
-- Name: FUNCTION swh_cache_content_get(target sha1_git); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_cache_content_get(target sha1_git) IS 'Retrieve cache content information';


--
-- Name: swh_cache_content_get_all(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_cache_content_get_all() RETURNS SETOF cache_content_signature
    LANGUAGE sql STABLE
    AS $$
    SELECT c.sha1, c.sha1_git, c.sha256, ccr.revision_paths
    FROM cache_content_revision ccr
    INNER JOIN content as c
    ON ccr.content = c.sha1_git
$$;


--
-- Name: FUNCTION swh_cache_content_get_all(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_cache_content_get_all() IS 'Retrieve batch of contents';


--
-- Name: swh_cache_content_revision_add(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_cache_content_revision_add() RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  cnt bigint;
  d sha1_git;
begin
  delete from tmp_bytea t where exists (select 1 from cache_content_revision_processed ccrp where t.id = ccrp.revision);

  select count(*) from tmp_bytea into cnt;
  if cnt <> 0 then
    create temporary table tmp_ccr (
        content sha1_git,
        directory sha1_git,
        path unix_path
    ) on commit drop;

    create temporary table tmp_ccrd (
        directory sha1_git,
        revision sha1_git
    ) on commit drop;

    insert into tmp_ccrd
      select directory, id as revision
      from tmp_bytea
      inner join revision using(id);

    insert into cache_content_revision_processed
      select distinct id from tmp_bytea order by id;

    for d in
      select distinct directory from tmp_ccrd
    loop
      insert into tmp_ccr
        select sha1_git as content, d as directory, name as path
        from swh_directory_walk(d)
        where type='file';
    end loop;

    with revision_contents as (
      select content, false as blacklisted, array_agg(ARRAY[revision::bytea, path::bytea]) as revision_paths
      from tmp_ccr
      inner join tmp_ccrd using (directory)
      group by content
      order by content
    ), updated_cache_entries as (
      update cache_content_revision ccr
      set revision_paths = ccr.revision_paths || rc.revision_paths
      from revision_contents rc
      where ccr.content = rc.content and ccr.blacklisted = false
      returning ccr.content
    ) insert into cache_content_revision
        select * from revision_contents rc
        where not exists (select 1 from updated_cache_entries uce where uce.content = rc.content)
        order by rc.content
      on conflict (content) do update
        set revision_paths = cache_content_revision.revision_paths || EXCLUDED.revision_paths
        where cache_content_revision.blacklisted = false;
    return;
  else
    return;
  end if;
end
$$;


--
-- Name: FUNCTION swh_cache_content_revision_add(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_cache_content_revision_add() IS 'Cache the revisions from tmp_bytea into cache_content_revision';


--
-- Name: swh_cache_revision_origin_add(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_cache_revision_origin_add(origin_id bigint, visit_id bigint) RETURNS SETOF sha1_git
    LANGUAGE plpgsql
    AS $$
declare
    visit_exists bool;
begin
  select true from origin_visit where origin = origin_id and visit = visit_id into visit_exists;

  if not visit_exists then
      return;
  end if;

  visit_exists := null;

  select true from cache_revision_origin where origin = origin_id and visit = visit_id limit 1 into visit_exists;

  if visit_exists then
      return;
  end if;

  return query with new_pointed_revs as (
    select swh_revision_from_target(target, target_type) as id
    from swh_occurrence_by_origin_visit(origin_id, visit_id)
  ),
  old_pointed_revs as (
    select swh_revision_from_target(target, target_type) as id
    from swh_occurrence_by_origin_visit(origin_id,
      (select visit from origin_visit where origin = origin_id and visit < visit_id order by visit desc limit 1))
  ),
  new_revs as (
    select distinct id
    from swh_revision_list(array(select id::bytea from new_pointed_revs where id is not null))
  ),
  old_revs as (
    select distinct id
    from swh_revision_list(array(select id::bytea from old_pointed_revs where id is not null))
  )
  insert into cache_revision_origin (revision, origin, visit)
  select n.id as revision, origin_id, visit_id from new_revs n
    where not exists (
    select 1 from old_revs o
    where o.id = n.id)
   returning revision;
end
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


--
-- Name: swh_content_ctags_add(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_ctags_add(conflict_update boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    if conflict_update then
        delete from content_ctags
        where id in (select distinct id from tmp_content_ctags);
    end if;

    insert into content_ctags (id, name, kind, line, lang)
    select id, name, kind, line, lang
    from tmp_content_ctags
        on conflict(id, md5(name), kind, line, lang)
        do nothing;
    return;
end
$$;


--
-- Name: FUNCTION swh_content_ctags_add(conflict_update boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_ctags_add(conflict_update boolean) IS 'Add new ctags symbols per content';


--
-- Name: swh_content_ctags_get(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_ctags_get() RETURNS SETOF content_ctags_signature
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select c.id, c.name, c.kind, c.line, c.lang
        from tmp_bytea t
        inner join content_ctags c using(id)
        order by line;
    return;
end
$$;


--
-- Name: FUNCTION swh_content_ctags_get(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_ctags_get() IS 'List content ctags';


--
-- Name: swh_content_ctags_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_ctags_missing() RETURNS SETOF sha1
    LANGUAGE plpgsql
    AS $$
begin
    return query
	(select id::sha1 from tmp_bytea as tmp
	 where not exists
	     (select 1 from content_ctags as c where c.id = tmp.id limit 1));
    return;
end
$$;


--
-- Name: FUNCTION swh_content_ctags_missing(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_ctags_missing() IS 'Filter missing content ctags';


--
-- Name: swh_content_ctags_search(text, integer, sha1); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_ctags_search(expression text, l integer DEFAULT 10, last_sha1 sha1 DEFAULT '\x0000000000000000000000000000000000000000'::bytea) RETURNS SETOF content_ctags_signature
    LANGUAGE sql
    AS $$
    select id, name, kind, line, lang
    from content_ctags
    where hash_sha1(name) = hash_sha1(expression)
    and id > last_sha1
    order by id
    limit l;
$$;


--
-- Name: FUNCTION swh_content_ctags_search(expression text, l integer, last_sha1 sha1); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_ctags_search(expression text, l integer, last_sha1 sha1) IS 'Equality search through ctags'' symbols';


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
-- Name: swh_content_find_provenance(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_find_provenance(content_id sha1_git) RETURNS SETOF content_provenance
    LANGUAGE sql
    AS $$
    with subscripted_paths as (
        select content, revision_paths, generate_subscripts(revision_paths, 1) as s
        from cache_content_revision
        where content = content_id
    ),
    cleaned_up_contents as (
        select content, revision_paths[s][1]::sha1_git as revision, revision_paths[s][2]::unix_path as path
        from subscripted_paths
    )
    select cuc.content, cuc.revision, cro.origin, cro.visit, cuc.path
    from cleaned_up_contents cuc
    inner join cache_revision_origin cro using(revision)
$$;


--
-- Name: FUNCTION swh_content_find_provenance(content_id sha1_git); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_find_provenance(content_id sha1_git) IS 'Given a content, provide provenance information on it';


--
-- Name: swh_content_fossology_license_add(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_fossology_license_add(conflict_update boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    if conflict_update then
        delete from content_fossology_license
        where id in (select distinct id from tmp_content_fossology_license);
    end if;

    insert into content_fossology_license (id, license_id, indexer_configuration_id)
    select tcl.id,
          (select id from fossology_license where name = tcl.license) as license,
          (select id from indexer_configuration where tool_name = tcl.tool_name
                                                and tool_version = tcl.tool_version)
                          as indexer_configuration_id
    from tmp_content_fossology_license tcl
        on conflict(id, license_id, indexer_configuration_id)
        do nothing;
    return;
end
$$;


--
-- Name: FUNCTION swh_content_fossology_license_add(conflict_update boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_fossology_license_add(conflict_update boolean) IS 'Add new content licenses';


--
-- Name: swh_content_fossology_license_get(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_fossology_license_get() RETURNS SETOF content_fossology_license_signature
    LANGUAGE plpgsql
    AS $$
begin
    return query
      select cl.id,
             ic.tool_name,
             ic.tool_version,
             array(select name
                   from fossology_license
                   where id = ANY(array_agg(cl.license_id))) as licenses
      from tmp_bytea tcl
      inner join content_fossology_license cl using(id)
      inner join indexer_configuration ic on ic.id=cl.indexer_configuration_id
      group by cl.id, ic.tool_name, ic.tool_version;
    return;
end
$$;


--
-- Name: FUNCTION swh_content_fossology_license_get(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_fossology_license_get() IS 'List content licenses';


--
-- Name: swh_content_fossology_license_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_fossology_license_missing() RETURNS SETOF sha1
    LANGUAGE plpgsql
    AS $$
begin
    return query
	(select id::sha1 from tmp_bytea as tmp
	 where not exists
	     (select 1 from content_fossology_license as c where c.id = tmp.id));
    return;
end
$$;


--
-- Name: FUNCTION swh_content_fossology_license_missing(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_fossology_license_missing() IS 'Filter missing content licenses';


--
-- Name: swh_content_fossology_license_unknown(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_fossology_license_unknown() RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select name from tmp_content_fossology_license_unknown t where not exists (
            select 1 from fossology_license where name=t.name
        );
end
$$;


--
-- Name: FUNCTION swh_content_fossology_license_unknown(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_fossology_license_unknown() IS 'List unknown licenses';


--
-- Name: swh_content_language_add(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_language_add(conflict_update boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    if conflict_update then
        insert into content_language (id, lang)
        select id, lang
    	from tmp_content_language
            on conflict(id)
                do update set lang = excluded.lang;

    else
        insert into content_language (id, lang)
        select id, lang
    	from tmp_content_language
            on conflict do nothing;
    end if;
    return;
end
$$;


--
-- Name: FUNCTION swh_content_language_add(conflict_update boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_language_add(conflict_update boolean) IS 'Add new content languages';


--
-- Name: content_language; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_language (
    id sha1 NOT NULL,
    lang languages NOT NULL
);


--
-- Name: TABLE content_language; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE content_language IS 'Language information on a raw content';


--
-- Name: COLUMN content_language.lang; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_language.lang IS 'Language information';


--
-- Name: swh_content_language_get(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_language_get() RETURNS SETOF content_language
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select id::sha1, lang
        from tmp_bytea t
        inner join content_language using(id);
    return;
end
$$;


--
-- Name: FUNCTION swh_content_language_get(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_language_get() IS 'List content languages';


--
-- Name: swh_content_language_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_language_missing() RETURNS SETOF sha1
    LANGUAGE plpgsql
    AS $$
begin
    return query
	(select id::sha1 from tmp_bytea as tmp
	 where not exists
	     (select 1 from content_language as c where c.id = tmp.id));
    return;
end
$$;


--
-- Name: FUNCTION swh_content_language_missing(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_language_missing() IS 'Filter missing content languages';


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
-- Name: swh_content_mimetype_add(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_mimetype_add(conflict_update boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
    if conflict_update then
        insert into content_mimetype (id, mimetype, encoding)
        select id, mimetype, encoding
        from tmp_content_mimetype
            on conflict(id)
                do update set mimetype = excluded.mimetype,
                    encoding = excluded.encoding;

    else
        insert into content_mimetype (id, mimetype, encoding)
        select id, mimetype, encoding
         from tmp_content_mimetype
            on conflict do nothing;
    end if;
    return;
end
$$;


--
-- Name: FUNCTION swh_content_mimetype_add(conflict_update boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_mimetype_add(conflict_update boolean) IS 'Add new content mimetypes';


--
-- Name: content_mimetype; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_mimetype (
    id sha1 NOT NULL,
    mimetype bytea NOT NULL,
    encoding bytea NOT NULL
);


--
-- Name: TABLE content_mimetype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE content_mimetype IS 'Metadata associated to a raw content';


--
-- Name: COLUMN content_mimetype.mimetype; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_mimetype.mimetype IS 'Raw content Mimetype';


--
-- Name: COLUMN content_mimetype.encoding; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_mimetype.encoding IS 'Raw content encoding';


--
-- Name: swh_content_mimetype_get(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_mimetype_get() RETURNS SETOF content_mimetype
    LANGUAGE plpgsql
    AS $$
begin
    return query
        select id::sha1, mimetype, encoding
        from tmp_bytea t
        inner join content_mimetype using(id);
    return;
end
$$;


--
-- Name: FUNCTION swh_content_mimetype_get(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_mimetype_get() IS 'List content mimetypes';


--
-- Name: swh_content_mimetype_missing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_content_mimetype_missing() RETURNS SETOF sha1
    LANGUAGE plpgsql
    AS $$
begin
    return query
	(select id::sha1 from tmp_bytea as tmp
	 where not exists
	     (select 1 from content_mimetype as c where c.id = tmp.id));
    return;
end
$$;


--
-- Name: FUNCTION swh_content_mimetype_missing(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_content_mimetype_missing() IS 'Filter missing content mimetype';


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
-- Name: swh_mktemp_content_fossology_license(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_content_fossology_license() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_content_fossology_license (
    id           sha1,
    tool_name    text,
    tool_version text,
    license      text
  ) on commit drop;
$$;


--
-- Name: FUNCTION swh_mktemp_content_fossology_license(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_mktemp_content_fossology_license() IS 'Helper table to add content license';


--
-- Name: swh_mktemp_content_fossology_license_unknown(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_mktemp_content_fossology_license_unknown() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_content_fossology_license_unknown (
    name       text not null
  ) on commit drop;
$$;


--
-- Name: FUNCTION swh_mktemp_content_fossology_license_unknown(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_mktemp_content_fossology_license_unknown() IS 'Helper table to list unknown licenses';


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
-- Name: occurrence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE occurrence (
    origin bigint NOT NULL,
    branch bytea NOT NULL,
    target sha1_git NOT NULL,
    target_type object_type NOT NULL
);


--
-- Name: swh_occurrence_by_origin_visit(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_occurrence_by_origin_visit(origin_id bigint, visit_id bigint) RETURNS SETOF occurrence
    LANGUAGE sql STABLE
    AS $$
  select origin, branch, target, target_type from occurrence_history
  where origin = origin_id and visit_id = ANY(visits);
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
-- Name: swh_revision_from_target(sha1_git, object_type); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_from_target(target sha1_git, target_type object_type) RETURNS sha1_git
    LANGUAGE plpgsql
    AS $$
#variable_conflict use_variable
begin
   while target_type = 'release' loop
       select r.target, r.target_type from release r where r.id = target into target, target_type;
   end loop;
   if target_type = 'revision' then
       return target;
   else
       return null;
   end if;
end
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
-- Name: swh_revision_walk(sha1_git); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_revision_walk(revision_id sha1_git) RETURNS SETOF directory_entry
    LANGUAGE sql STABLE
    AS $$
  select dir_id, type, target, name, perms, status, sha1, sha1_git, sha256
  from swh_directory_walk((select directory from revision where id=revision_id))
$$;


--
-- Name: FUNCTION swh_revision_walk(revision_id sha1_git); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_revision_walk(revision_id sha1_git) IS 'Recursively list the revision targeted directory arborescence';


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
-- Name: cache_content_revision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE cache_content_revision (
    content sha1_git NOT NULL,
    blacklisted boolean DEFAULT false,
    revision_paths bytea[]
);


--
-- Name: cache_content_revision_processed; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE cache_content_revision_processed (
    revision sha1_git NOT NULL
);


--
-- Name: cache_revision_origin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE cache_revision_origin (
    revision sha1_git NOT NULL,
    origin bigint NOT NULL,
    visit bigint NOT NULL
);


--
-- Name: content_ctags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_ctags (
    id sha1 NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    line bigint NOT NULL,
    lang ctags_languages NOT NULL
);


--
-- Name: TABLE content_ctags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE content_ctags IS 'Ctags information on a raw content';


--
-- Name: COLUMN content_ctags.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_ctags.id IS 'Content identifier';


--
-- Name: COLUMN content_ctags.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_ctags.name IS 'Symbol name';


--
-- Name: COLUMN content_ctags.kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_ctags.kind IS 'Symbol kind (function, class, variable, const...)';


--
-- Name: COLUMN content_ctags.line; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_ctags.line IS 'Symbol line';


--
-- Name: COLUMN content_ctags.lang; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_ctags.lang IS 'Language information for that content';


--
-- Name: content_fossology_license; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE content_fossology_license (
    id sha1 NOT NULL,
    license_id smallint NOT NULL,
    indexer_configuration_id bigint NOT NULL
);


--
-- Name: TABLE content_fossology_license; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE content_fossology_license IS 'license associated to a raw content';


--
-- Name: COLUMN content_fossology_license.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_fossology_license.id IS 'Raw content identifier';


--
-- Name: COLUMN content_fossology_license.license_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN content_fossology_license.license_id IS 'One of the content''s license identifier';


--
-- Name: content_fossology_license_indexer_configuration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE content_fossology_license_indexer_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_fossology_license_indexer_configuration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE content_fossology_license_indexer_configuration_id_seq OWNED BY content_fossology_license.indexer_configuration_id;


--
-- Name: content_fossology_license_license_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE content_fossology_license_license_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_fossology_license_license_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE content_fossology_license_license_id_seq OWNED BY content_fossology_license.license_id;


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
-- Name: fossology_license; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE fossology_license (
    id smallint NOT NULL,
    name text NOT NULL
);


--
-- Name: TABLE fossology_license; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE fossology_license IS 'Possible license recognized by license indexer';


--
-- Name: COLUMN fossology_license.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN fossology_license.id IS 'License identifier';


--
-- Name: COLUMN fossology_license.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN fossology_license.name IS 'License name';


--
-- Name: fossology_license_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE fossology_license_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fossology_license_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE fossology_license_id_seq OWNED BY fossology_license.id;


--
-- Name: indexer_configuration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE indexer_configuration (
    id integer NOT NULL,
    tool_name text NOT NULL,
    tool_version text NOT NULL,
    tool_configuration jsonb
);


--
-- Name: TABLE indexer_configuration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE indexer_configuration IS 'Indexer''s configuration version';


--
-- Name: COLUMN indexer_configuration.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN indexer_configuration.id IS 'Tool identifier';


--
-- Name: COLUMN indexer_configuration.tool_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN indexer_configuration.tool_version IS 'Tool version';


--
-- Name: COLUMN indexer_configuration.tool_configuration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN indexer_configuration.tool_configuration IS 'Tool configuration: command line, flags, etc...';


--
-- Name: indexer_configuration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE indexer_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: indexer_configuration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE indexer_configuration_id_seq OWNED BY indexer_configuration.id;


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
-- Name: content object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY content ALTER COLUMN object_id SET DEFAULT nextval('content_object_id_seq'::regclass);


--
-- Name: content_fossology_license license_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_fossology_license ALTER COLUMN license_id SET DEFAULT nextval('content_fossology_license_license_id_seq'::regclass);


--
-- Name: content_fossology_license indexer_configuration_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_fossology_license ALTER COLUMN indexer_configuration_id SET DEFAULT nextval('content_fossology_license_indexer_configuration_id_seq'::regclass);


--
-- Name: directory object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory ALTER COLUMN object_id SET DEFAULT nextval('directory_object_id_seq'::regclass);


--
-- Name: directory_entry_dir id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_dir ALTER COLUMN id SET DEFAULT nextval('directory_entry_dir_id_seq'::regclass);


--
-- Name: directory_entry_file id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_file ALTER COLUMN id SET DEFAULT nextval('directory_entry_file_id_seq'::regclass);


--
-- Name: directory_entry_rev id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_rev ALTER COLUMN id SET DEFAULT nextval('directory_entry_rev_id_seq'::regclass);


--
-- Name: entity_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_history ALTER COLUMN id SET DEFAULT nextval('entity_history_id_seq'::regclass);


--
-- Name: fetch_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY fetch_history ALTER COLUMN id SET DEFAULT nextval('fetch_history_id_seq'::regclass);


--
-- Name: fossology_license id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY fossology_license ALTER COLUMN id SET DEFAULT nextval('fossology_license_id_seq'::regclass);


--
-- Name: indexer_configuration id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY indexer_configuration ALTER COLUMN id SET DEFAULT nextval('indexer_configuration_id_seq'::regclass);


--
-- Name: list_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history ALTER COLUMN id SET DEFAULT nextval('list_history_id_seq'::regclass);


--
-- Name: occurrence_history object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history ALTER COLUMN object_id SET DEFAULT nextval('occurrence_history_object_id_seq'::regclass);


--
-- Name: origin id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin ALTER COLUMN id SET DEFAULT nextval('origin_id_seq'::regclass);


--
-- Name: person id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person ALTER COLUMN id SET DEFAULT nextval('person_id_seq'::regclass);


--
-- Name: release object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY release ALTER COLUMN object_id SET DEFAULT nextval('release_object_id_seq'::regclass);


--
-- Name: revision object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision ALTER COLUMN object_id SET DEFAULT nextval('revision_object_id_seq'::regclass);


--
-- Name: skipped_content object_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY skipped_content ALTER COLUMN object_id SET DEFAULT nextval('skipped_content_object_id_seq'::regclass);


--
-- Data for Name: cache_content_revision; Type: TABLE DATA; Schema: public; Owner: -
--

COPY cache_content_revision (content, blacklisted, revision_paths) FROM stdin;
\.


--
-- Data for Name: cache_content_revision_processed; Type: TABLE DATA; Schema: public; Owner: -
--

COPY cache_content_revision_processed (revision) FROM stdin;
\.


--
-- Data for Name: cache_revision_origin; Type: TABLE DATA; Schema: public; Owner: -
--

COPY cache_revision_origin (revision, origin, visit) FROM stdin;
\.


--
-- Data for Name: content; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content (sha1, sha1_git, sha256, length, ctime, status, object_id) FROM stdin;
\.


--
-- Data for Name: content_ctags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content_ctags (id, name, kind, line, lang) FROM stdin;
\.


--
-- Data for Name: content_fossology_license; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content_fossology_license (id, license_id, indexer_configuration_id) FROM stdin;
\.


--
-- Name: content_fossology_license_indexer_configuration_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('content_fossology_license_indexer_configuration_id_seq', 1, false);


--
-- Name: content_fossology_license_license_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('content_fossology_license_license_id_seq', 1, false);


--
-- Data for Name: content_language; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content_language (id, lang) FROM stdin;
\.


--
-- Data for Name: content_mimetype; Type: TABLE DATA; Schema: public; Owner: -
--

COPY content_mimetype (id, mimetype, encoding) FROM stdin;
\.


--
-- Name: content_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('content_object_id_seq', 1, false);


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
96	2016-12-01 10:30:30.332615+01	Work In Progress
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
5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	1
6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	2
7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	2016-12-01 10:30:30.332615+01	3
4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	4
5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	5
4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	6
aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	7
34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	8
e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	9
9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	10
ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	2016-12-01 10:30:30.332615+01	11
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
1	5f4d4c51-498a-4e28-88b3-b3e4e8396cba	\N	softwareheritage	organization	Software Heritage	http://www.softwareheritage.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
2	6577984d-64c8-4fab-b3ea-3cf63ebb8589	\N	gnu	organization	GNU is not UNIX	https://gnu.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
3	7c33636b-8f11-4bda-89d9-ba8b76a42cec	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Hosting	group_of_entities	GNU Hosting facilities	\N	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
4	4706c92a-8173-45d9-93d7-06523f249398	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU rsync mirror	hosting	GNU rsync mirror	rsync://mirror.gnu.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
5	5cb20137-c052-4097-b7e9-e1020172c48e	6577984d-64c8-4fab-b3ea-3cf63ebb8589	GNU Projects	group_of_entities	GNU Projects	https://gnu.org/software/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
6	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	\N	GitHub	organization	GitHub	https://github.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Hosting	group_of_entities	GitHub Hosting facilities	https://github.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
8	34bd6b1b-463f-43e5-a697-785107f598e4	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub git hosting	hosting	GitHub git hosting	https://github.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
9	e8c3fc2e-a932-4fd7-8f8e-c40645eb35a7	aee991a0-f8d7-4295-a201-d1ce2efc9fb2	GitHub asset hosting	hosting	GitHub asset hosting	https://github.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
10	9f7b34d9-aa98-44d4-8907-b332c1036bc3	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Organizations	group_of_entities	GitHub Organizations	https://github.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
11	ad6df473-c1d2-4f40-bc58-2b091d4a750e	4bfb38f6-f8cd-4bc2-b256-5db689bb8da4	GitHub Users	group_of_entities	GitHub Users	https://github.org/	t	f	\N	\N	{"2016-12-01 10:30:30.332615+01"}
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
-- Data for Name: fossology_license; Type: TABLE DATA; Schema: public; Owner: -
--

COPY fossology_license (id, name) FROM stdin;
1	3DFX
2	3DFX-PL
3	AAL
4	ACAA
5	ACDL
6	ACE
7	Adaptec-GPL
8	Adaptec.RESTRICTED
9	Adobe
10	Adobe-AFM
11	Adobe-EULA
12	Adobe-SCLA
13	AFL
14	AFL-1.0
15	AFL-1.1
16	AFL-1.2
17	AFL-2.0
18	AFL-2.1
19	AFL-3.0
20	AFPL-Ghostscript
21	AgainstDRM
22	AGE-Logic
23	Agere-EULA
24	AGFA-EULA
25	AGFA(RESTRICTED)
26	AGPL
27	AGPL-1.0
28	AGPL-1.0+
29	AGPL-3.0
30	AGPL-3.0+
31	AGFA.RESTRICTED
32	Aladdin
33	Alfresco
34	Alfresco-FLOSS
35	Algorithmics
36	AMD
37	AMD-EULA
38	AML
39	AndroidFraunhofer.Commercial
40	AndroidSDK.Commercial
41	ANTLR-PD
42	AOL-EULA
43	Apache
44	Apache-1.0
45	Apache-1.1
46	Apache-2.0
47	Apache-style
48	Apache-v1.0
49	APL
50	APL-1.0
51	Apple
52	Apple-EULA
53	Apple.FontForge
54	Apple.Sample
55	APSL
56	APSL-1.0
57	APSL-1.1
58	APSL-1.2
59	APSL-2.0
60	APSL-style
61	Aptana
62	Aptana-1.0
63	ARJ
64	Arphic-Font-PL
65	Arphic-style
66	Artifex
67	Artistic-1.0
68	Artistic-1.0-cl8
69	Artistic-1.0-Perl
70	Artistic-2.0
71	Ascender-EULA
72	ATI-EULA
73	ATMEL-FW
74	ATT
75	ATT.Non-commercial
76	ATT-Source
77	ATT-Source-1.0
78	ATT-Source-1.2d
79	ATT-style
80	AVM
81	Baekmuk-Font
82	Baekmuk.Hwan
83	BancTec
84	BEA
85	Beerware
86	Bellcore
87	Bellcore-style
88	BH-Font
89	BH-Font-style
90	BISON
91	Bitstream
92	BitTorrent
93	BitTorrent-1.0
94	BitTorrent-1.1
95	BIZNET
96	BIZNET-style
97	BrainStorm-EULA
98	Broadcom.Commercial
99	Broadcom-EULA
100	BSD
101	BSD-2-Clause
102	BSD-2-Clause-FreeBSD
103	BSD-2-Clause-NetBSD
104	BSD-3-Clause
105	BSD-3-Clause-Clear
106	BSD-3-Clause-Severability
107	BSD-4-Clause
108	BSD-4-Clause-UC
109	BSD.non-commercial
110	BSD-style
111	BSL-1.0
112	BSL-style
113	CA
114	Cadence
115	Catharon
116	CATOSL
117	CATOSL-1.1
118	CC0-1.0
119	CC-BY
120	CC-BY-1.0
121	CC-BY-2.0
122	CC-BY-2.5
123	CC-BY-3.0
124	CC-BY-4.0
125	CC-BY-NC-1.0
126	CC-BY-NC-2.0
127	CC-BY-NC-2.5
128	CC-BY-NC-3.0
129	CC-BY-NC-4.0
130	CC-BY-NC-ND-1.0
131	CC-BY-NC-ND-2.0
132	CC-BY-NC-ND-2.5
133	CC-BY-NC-ND-3.0
134	CC-BY-NC-ND-4.0
135	CC-BY-NC-SA-1.0
136	CC-BY-NC-SA-2.0
137	CC-BY-NC-SA-2.5
138	CC-BY-NC-SA-3.0
139	CC-BY-NC-SA-4.0
140	CC-BY-ND-1.0
141	CC-BY-ND-2.0
142	CC-BY-ND-2.5
143	CC-BY-ND-3.0
144	CC-BY-ND-4.0
145	CC-BY-SA
146	CC-BY-SA-1.0
147	CC-BY-SA-2.0
148	CC-BY-SA-2.5
149	CC-BY-SA-3.0
150	CC-BY-SA-4.0
151	CC-LGPL
152	CC-LGPL-2.1
153	CCLRC
154	CCPL
155	CDDL
156	CDDL-1.0
157	CDDL-1.1
158	CECILL
159	CECILL-1.0
160	CECILL-1.1
161	CECILL-2.0
162	CECILL-B
163	CECILL-C
164	CECILL(dual)
165	Cisco
166	Cisco-style
167	Citrix
168	ClArtistic
169	ClearSilver
170	CMake
171	CMU
172	CMU-style
173	CNRI-Python
174	CNRI-Python-GPL-Compatible
175	Combined_OpenSSL+SSLeay
176	COMMERCIAL
177	CompuServe
178	Comtrol
179	Condor-1.0
180	Condor-1.1
181	CopyLeft[1]
182	CopyLeft[2]
183	CPAL
184	CPAL-1.0
185	CPL
186	CPL-0.5
187	CPL-1.0
188	CPOL
189	CPOL-1.02
190	Cryptogams
191	CUA-OPL-1.0
192	CUPS
193	CUPS-EULA
194	Cygnus-eCos-1.0
195	Cylink-ISC
196	Cypress-FW
197	DARPA
198	DARPA-Cougaar
199	Debian-social-DFSG
200	Debian-SPI
201	Debian-SPI-style
202	D.E.Knuth
203	D-FSL-1.0
204	DMTF
205	DOCBOOK
206	DOCBOOK-style
207	DPTC
208	DSCT
209	DSL
210	Dual-license
211	Dyade
212	EBT-style
213	ECL-1.0
214	ECL-2.0
215	eCos-2.0
216	EDL-1.0
217	EFL
218	EFL-1.0
219	EFL-2.0
220	eGenix
221	Entessa
222	Epinions
223	EPL
224	EPL-1.0
225	Epson-EULA
226	Epson-PL
227	ErlPL-1.1
228	EUDatagrid
229	EUPL-1.0
230	EUPL-1.1
231	FaCE
232	Fair
233	Fair-style
234	FAL-1.0
235	FAL-1.3
236	Fedora
237	FedoraCLA
238	Flash2xml-1.0
239	Flora
240	Flora-1.0
241	Flora-1.1
242	Frameworx
243	Frameworx-1.0
244	FreeBSD-Doc
245	Free-PL
246	Free-SW
247	Free-SW.run-COMMAND
248	FSF
249	FTL
250	FTL-style
251	Fujitsu
252	Garmin-EULA
253	GFDL
254	GFDL-1.1
255	GFDL-1.1+
256	GFDL-1.2
257	GFDL-1.2+
258	GFDL-1.3
259	GFDL-v1.2
260	Genivia.Commercial
261	Ghostscript-GPL
262	Ghostscript-GPL-1.1
263	Giftware
264	GNU-copyleft
265	GNU-Ghostscript
266	GNU-javamail-exception
267	GNU-Manpages
268	GNU-style.EXECUTE
269	GNU-style.interactive
270	Google
271	Google-BSD
272	Govt-restrict
273	Govt-rights
274	Govt-work
275	GPDL
276	GPL
277	GPL-1.0
278	GPL-1.0+
279	GPL-2.0
280	GPL-2.0+
281	GPL-2.0-with-autoconf-exception
282	GPL-2.0-with-bison-exception
283	GPL-2.0+-with-bison-exception
284	GPL-2.0-with-classpath-exception
285	GPL-2.0+-with-classpath-exception
286	GPL-2.0-with-font-exception
287	GPL-2.0-with-GCC-exception
288	GPL-2.0-with-trolltech-exception
289	GPL-2.0+-with-UPX-exception
290	GPL-3.0
291	GPL-3.0+
292	GPL-3.0-with-autoconf-exception
293	GPL-3.0+-with-autoconf-exception
294	GPL-3.0-with-bison-exception
295	GPL-3.0+-with-bison-exception
296	GPL-3.0-with-classpath-exception
297	GPL-3.0+-with-classpath-exception
298	GPL-3.0-with-GCC-exception
299	GPL-3.0+-with-GCC-exception
300	GPL-exception
301	GPL-or-LGPL
302	GPL(rms)
303	GPL-with-autoconf-exception
304	gSOAP
305	gSOAP-1.3b
306	H2
307	H2-1.0
308	Hacktivismo
309	Hauppauge
310	Helix.RealNetworks-EULA
311	HP
312	HP-Compaq
313	HP-DEC
314	HP-DEC-style
315	HP-EULA
316	HP+IBM
317	HPND
318	HP-Proprietary
319	HP-style
320	HSQLDB
321	IBM
322	IBM-Courier
323	IBM-EULA
324	IBM-JCL
325	IBM-pibs
326	IBM-reciprocal
327	ICU
328	ID-EULA
329	IDPL
330	IDPL-1.0
331	IEEE-Doc
332	IETF
333	IETF-style
334	IJG
335	ImageMagick
336	ImageMagick-style
337	Imlib2
338	InfoSeek
339	info-zip
340	InnerNet
341	InnerNet-2.00
342	InnerNet-style
343	Intel
344	Intel.Commercial
345	Intel-EULA
346	Intel-other
347	Intel.RESTRICTED
348	Intel-WLAN
349	Interbase-1.0
350	Interbase-PL
351	Interlink-EULA
352	Intranet-only
353	IOS
354	IoSoft.COMMERCIAL
355	IPA
356	IPA-Font-EULA
357	IP-claim
358	IPL
359	IPL-1.0
360	IPL-2.0
361	IPTC
362	IronDoc
363	ISC
364	Jabber
365	Jabber-1.0
366	Java-Multi-Corp
367	Java-WSDL4J
368	Java-WSDL-Policy
369	Java-WSDL-Schema
370	Java-WSDL-Spec
371	JISP
372	JPEG.netpbm
373	JPNIC
374	JSON
375	KDE
376	KD-Tools-EULA
377	Keyspan-FW
378	KnowledgeTree-1.1
379	Knuth-style
380	Lachman-Proprietary
381	Larabie-EULA
382	LDP
383	LDP-1A
384	LDP-2.0
385	Legato
386	Leptonica
387	LGPL
388	LGPL-1.0
389	LGPL-1.0+
390	LGPL-2.0
391	LGPL-2.0+
392	LGPL-2.1
393	LGPL-2.1+
394	LGPL-3.0
395	LGPL-3.0+
396	LIBGCJ
397	Libpng
398	Link-exception
399	LinuxDoc
400	Linux-HOWTO
401	Logica-OSL-1.0
402	LPL-1.0
403	LPL-1.02
404	LPPL
405	LPPL-1.0
406	LPPL-1.0+
407	LPPL-1.1
408	LPPL-1.1+
409	LPPL-1.2
410	LPPL-1.2+
411	LPPL-1.3
412	LPPL-1.3+
413	LPPL-1.3a
414	LPPL-1.3a+
415	LPPL-1.3b
416	LPPL-1.3b+
417	LPPL-1.3c
418	LPPL-1.3c+
419	MacroMedia-RPSL
420	Macrovision
421	Macrovision-EULA
422	Majordomo
423	Majordomo-1.1
424	Mandriva
425	Mellanox
426	MetroLink
427	MetroLink-nonfree
428	Mibble
429	Mibble-2.8
430	Microsoft
431	Migemo
432	MindTerm
433	MirOS
434	MIT
435	MIT.BSD
436	MIT&BSD
437	MITEM
438	Mitre
439	MitreCVW
440	MitreCVW-style
441	MIT-style
442	Motorola
443	Motosoto
444	MPEG3-decoder
445	MPL
446	MPL-1.0
447	MPL-1.1
448	MPL-1.1+
449	MPL-1.1-style
450	MPL-2.0
451	MPL-2.0-no-copyleft-exception
452	MPL-EULA-1.1
453	MPL-EULA-2.0
454	MPL-EULA-3.0
455	MPL-style
456	MPL.TPL
457	MPL.TPL-1.0
458	M-Plus-Project
459	MRL
460	MS-EULA
461	MS-indemnity
462	MS-IP
463	MS-LPL
464	MS-LRL
465	MS-PL
466	MS-RL
467	MS-SSL
468	Multics
469	MX4J
470	MX4J-1.0
471	MySQL-0.3
472	MySQL.FLOSS
473	MySQL-style
474	NASA
475	NASA-1.3
476	Naumen
477	NBPL-1.0
478	nCipher
479	NCSA
480	NESSUS-EULA
481	NGPL
482	Nokia
483	No_license_found
484	non-ATT-BSD
485	Non-commercial
486	Non-profit
487	NOSL
488	NOSL-1.0
489	Not-for-sale
490	Not-Free
491	Not-Internet
492	Not-OpenSource
493	NOT-Open-Source
494	NotreDame
495	NotreDame-style
496	Novell
497	Novell-EULA
498	Novell-IP
499	NPL
500	NPL-1.0
501	NPL-1.1
502	NPL-1.1+
503	NPL-EULA
504	NPOSL-3.0
505	NRL
506	NTP
507	Nvidia
508	Nvidia-EULA
509	OASIS
510	OCL
511	OCL-1.0
512	OCLC
513	OCLC-1.0
514	OCLC-2.0
515	OCL-style
516	ODbL-1.0
517	ODL
518	OFL-1.0
519	OFL-1.1
520	OGTSL
521	OLDAP
522	OLDAP-1.1
523	OLDAP-1.2
524	OLDAP-1.3
525	OLDAP-1.4
526	OLDAP-2.0
527	OLDAP-2.0.1
528	OLDAP-2.1
529	OLDAP-2.2
530	OLDAP-2.2.1
531	OLDAP-2.2.2
532	OLDAP-2.3
533	OLDAP-2.4
534	OLDAP-2.5
535	OLDAP-2.6
536	OLDAP-2.7
537	OLDAP-2.8
538	OLDAP-style
539	OMF
540	OMRON
541	Ontopia
542	OpenCASCADE-PL
543	OpenGroup
544	OpenGroup-Proprietary
545	OpenGroup-style
546	OpenMap
547	OpenMarket
548	Open-PL
549	Open-PL-0.4
550	Open-PL-1.0
551	Open-PL-style
552	OpenSSL
553	OpenSSL-exception
554	OPL-1.0
555	OPL-style
556	Oracle-Berkeley-DB
557	Oracle-Dev
558	Oracle-EULA
559	OReilly
560	OReilly-style
561	OSD
562	OSF
563	OSF-style
564	OSL
565	OSL-1.0
566	OSL-1.1
567	OSL-2.0
568	OSL-2.1
569	OSL-3.0
570	Paradigm
571	Patent-ref
572	PDDL-1.0
573	Phorum
574	PHP
575	PHP-2.0
576	PHP-2.0.2
577	PHP-3.0
578	PHP-3.01
579	PHP-style
580	Piriform
581	Pixware-EULA
582	Platform-Computing(RESTRICTED)
583	Polyserve-CONFIDENTIAL
584	Postfix
585	PostgreSQL
586	Powder-Proprietary
587	Princeton
588	Princeton-style
589	Proprietary
590	Public-domain
591	Public-domain(C)
592	Public-domain-ref
593	Public-Use
594	Public-Use-1.0
595	Python
596	Python-2.0
597	Python-2.0.1
598	Python-2.0.2
599	Python-2.1.1
600	Python-2.1.3
601	Python-2.2
602	Python-2.2.3
603	Python-2.2.7
604	Python-2.3
605	Python-2.3.7
606	Python-2.4.4
607	Python-style
608	Qmail
609	QPL
610	QPL-1.0
611	QT.Commercial
612	QuarterDeck
613	Quest-EULA
614	RCSL
615	RCSL-1.0
616	RCSL-2.0
617	RCSL-3.0
618	RealNetworks-EULA
619	RedHat
620	RedHat-EULA
621	RedHat.Non-commercial
622	RedHat-specific
623	Redland
624	Restricted-rights
625	RHeCos-1.1
626	Riverbank-EULA
627	RPL
628	RPL-1.0
629	RPL-1.1
630	RPL-1.5
631	RPSL
632	RPSL-1.0
633	RPSL-2.0
634	RPSL-3.0
635	RSA-DNS
636	RSA-Security
637	RSCPL
638	Ruby
639	Same-license-as
640	SAX-PD
641	SciTech
642	SCO.commercial
643	SCSL
644	SCSL-2.3
645	SCSL-3.0
646	SCSL-TSA
647	SCSL-TSA-1.0
648	See-doc.OTHER
649	See-file
650	See-file.COPYING
651	See-file.LICENSE
652	See-file.README
653	See-URL
654	Sendmail
655	SGI
656	SGI-B-1.0
657	SGI-B-1.1
658	SGI-B-2.0
659	SGI-Freeware
660	SGI_GLX
661	SGI_GLX-1.0
662	SGI-Proprietary
663	SGI-style
664	SGML
665	SimPL-2.0
666	SISSL
667	SISSL-1.1
668	SISSL-1.2
669	Skype-EULA
670	Sleepycat
671	Sleepycat.Non-commercial
672	SMLNJ
673	SNIA
674	SNIA-1.0
675	SNIA-1.1
676	SpikeSource
677	SPL
678	SPL-1.0
679	Stanford
680	Stanford-style
681	SugarCRM-1.1.3
682	Sun
683	SUN
684	Sun-BCLA
685	Sun-BCLA-1.5.0
686	Sun-EULA
687	Sun-IP
688	Sun-Java
689	Sun.Non-commercial
690	SunPro
691	Sun-Proprietary
692	Sun.RESTRICTED
693	Sun-RPC
694	Sun-SCA
695	Sun(tm)
696	SW-Research
697	Tapjoy
698	TCL
699	Tektronix
700	Tektronix-style
701	TeX-exception
702	Trident-EULA
703	Trolltech
704	TrueCrypt-3.0
705	U-BC
706	U-Cambridge
707	U-Cambridge-style
708	UCAR
709	UCAR-style
710	U-Chicago
711	U-Columbia
712	UCWare-EULA
713	U-Del
714	U-Del-style
715	U-Edinburgh
716	U-Edinburgh-style
717	U-Michigan
718	U-Mich-style
719	U-Monash
720	Unicode
721	Unidex
722	UnitedLinux-EULA
723	Unix-Intl
724	Unlicense
725	unRAR restriction
726	URA.govt
727	USC
728	USC.Non-commercial
729	USC-style
730	US-Export-restrict
731	USL-Europe
732	U-Utah
733	U-Wash.Free-Fork
734	U-Washington
735	U-Wash-style
736	VIM
737	Vixie
738	Vixie-license
739	VMware-EULA
740	VSL-1.0
741	W3C
742	W3C-IP
743	W3C-style
744	Wash-U-StLouis
745	Wash-U-style
746	Watcom
747	Watcom-1.0
748	WebM
749	Wintertree
750	WordNet-3.0
751	WTFPL
752	WTI.Not-free
753	WXwindows
754	X11
755	X11-style
756	Xerox
757	Xerox-style
758	XFree86
759	XFree86-1.0
760	XFree86-1.1
761	Ximian
762	Ximian-1.0
763	XMLDB-1.0
764	Xnet
765	X/Open
766	XOPEN-EULA
767	X/Open-style
768	Yahoo-EULA
769	YaST.SuSE
770	YPL
771	YPL-1.0
772	YPL-1.1
773	Zend-1.0
774	Zend-2.0
775	Zeus
776	Zimbra
777	Zimbra-1.2
778	Zimbra-1.3
779	Zlib
780	Zlib-possibility
781	ZoneAlarm-EULA
782	ZPL
783	ZPL-1.0
784	ZPL-1.1
785	ZPL-2.0
786	ZPL-2.1
787	Zveno
788	Affero-possibility
789	Apache-possibility
790	Apache_v2-possibility
791	Artistic-possibility
792	BSD-possibility
793	CMU-possibility
794	CPL-possibility
795	Freeware
796	FSF-possibility
797	GPL-2.0+:3.0
798	GPL-2.0+&GPL-3.0+
799	GPL-2.1[sic]
800	GPL-2.1+[sic]
801	GPL-possibility
802	HP-possibility
803	IBM-possibility
804	ISC-possibility
805	LGPL-possibility
806	LGPL_v3-possibility
807	Microsoft-possibility
808	MIT-possibility
809	NOT-public-domain
810	Perl-possibility
811	PHP-possibility
812	RSA-possibility
813	Sun-possibility
814	Trademark-ref
815	UnclassifiedLicense
816	W3C-possibility
817	X11-possibility
\.


--
-- Name: fossology_license_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('fossology_license_id_seq', 817, true);


--
-- Data for Name: indexer_configuration; Type: TABLE DATA; Schema: public; Owner: -
--

COPY indexer_configuration (id, tool_name, tool_version, tool_configuration) FROM stdin;
1	nomos	3.1.0rc2-31-ga2cbb8c	{"command_line": "nomossa"}
\.


--
-- Name: indexer_configuration_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('indexer_configuration_id_seq', 1, true);


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
-- Name: cache_content_revision cache_content_revision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_content_revision
    ADD CONSTRAINT cache_content_revision_pkey PRIMARY KEY (content);


--
-- Name: cache_content_revision_processed cache_content_revision_processed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_content_revision_processed
    ADD CONSTRAINT cache_content_revision_processed_pkey PRIMARY KEY (revision);


--
-- Name: cache_revision_origin cache_revision_origin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_revision_origin
    ADD CONSTRAINT cache_revision_origin_pkey PRIMARY KEY (revision, origin, visit);


--
-- Name: content_language content_language_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_language
    ADD CONSTRAINT content_language_pkey PRIMARY KEY (id);


--
-- Name: content_mimetype content_mimetype_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_mimetype
    ADD CONSTRAINT content_mimetype_pkey PRIMARY KEY (id);


--
-- Name: content content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content
    ADD CONSTRAINT content_pkey PRIMARY KEY (sha1);


--
-- Name: dbversion dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: directory_entry_dir directory_entry_dir_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_dir
    ADD CONSTRAINT directory_entry_dir_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_file directory_entry_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_file
    ADD CONSTRAINT directory_entry_file_pkey PRIMARY KEY (id);


--
-- Name: directory_entry_rev directory_entry_rev_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory_entry_rev
    ADD CONSTRAINT directory_entry_rev_pkey PRIMARY KEY (id);


--
-- Name: directory directory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY directory
    ADD CONSTRAINT directory_pkey PRIMARY KEY (id);


--
-- Name: entity_equivalence entity_equivalence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_equivalence
    ADD CONSTRAINT entity_equivalence_pkey PRIMARY KEY (entity1, entity2);


--
-- Name: entity_history entity_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_history
    ADD CONSTRAINT entity_history_pkey PRIMARY KEY (id);


--
-- Name: entity entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (uuid);


--
-- Name: fetch_history fetch_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY fetch_history
    ADD CONSTRAINT fetch_history_pkey PRIMARY KEY (id);


--
-- Name: fossology_license fossology_license_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY fossology_license
    ADD CONSTRAINT fossology_license_pkey PRIMARY KEY (id);


--
-- Name: indexer_configuration indexer_configuration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY indexer_configuration
    ADD CONSTRAINT indexer_configuration_pkey PRIMARY KEY (id);


--
-- Name: list_history list_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history
    ADD CONSTRAINT list_history_pkey PRIMARY KEY (id);


--
-- Name: listable_entity listable_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY listable_entity
    ADD CONSTRAINT listable_entity_pkey PRIMARY KEY (uuid);


--
-- Name: occurrence_history occurrence_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_pkey PRIMARY KEY (object_id);


--
-- Name: occurrence occurrence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence
    ADD CONSTRAINT occurrence_pkey PRIMARY KEY (origin, branch);


--
-- Name: origin origin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin
    ADD CONSTRAINT origin_pkey PRIMARY KEY (id);


--
-- Name: origin_visit origin_visit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin_visit
    ADD CONSTRAINT origin_visit_pkey PRIMARY KEY (origin, visit);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: release release_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_pkey PRIMARY KEY (id);


--
-- Name: revision_history revision_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision_history
    ADD CONSTRAINT revision_history_pkey PRIMARY KEY (id, parent_rank);


--
-- Name: revision revision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision
    ADD CONSTRAINT revision_pkey PRIMARY KEY (id);


--
-- Name: skipped_content skipped_content_sha1_sha1_git_sha256_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY skipped_content
    ADD CONSTRAINT skipped_content_sha1_sha1_git_sha256_key UNIQUE (sha1, sha1_git, sha256);


--
-- Name: cache_revision_origin_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cache_revision_origin_revision_idx ON cache_revision_origin USING btree (revision);


--
-- Name: content_ctags_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_ctags_id_idx ON content_ctags USING btree (id);


--
-- Name: content_ctags_id_md5_kind_line_lang_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX content_ctags_id_md5_kind_line_lang_idx ON content_ctags USING btree (id, md5(name), kind, line, lang);


--
-- Name: content_ctags_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_ctags_name_idx ON content_ctags USING btree (name);


--
-- Name: content_ctime_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_ctime_idx ON content USING btree (ctime);


--
-- Name: content_fossology_license_id_license_id_indexer_configurati_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX content_fossology_license_id_license_id_indexer_configurati_idx ON content_fossology_license USING btree (id, license_id, indexer_configuration_id);


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
-- Name: fossology_license_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX fossology_license_name_idx ON fossology_license USING btree (name);


--
-- Name: indexer_configuration_tool_name_tool_version_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX indexer_configuration_tool_name_tool_version_idx ON indexer_configuration USING btree (tool_name, tool_version);


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
-- Name: content notify_new_content; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_content AFTER INSERT ON content FOR EACH ROW EXECUTE PROCEDURE notify_new_content();


--
-- Name: directory notify_new_directory; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_directory AFTER INSERT ON directory FOR EACH ROW EXECUTE PROCEDURE notify_new_directory();


--
-- Name: origin notify_new_origin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_origin AFTER INSERT ON origin FOR EACH ROW EXECUTE PROCEDURE notify_new_origin();


--
-- Name: origin_visit notify_new_origin_visit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_origin_visit AFTER INSERT ON origin_visit FOR EACH ROW EXECUTE PROCEDURE notify_new_origin_visit();


--
-- Name: release notify_new_release; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_release AFTER INSERT ON release FOR EACH ROW EXECUTE PROCEDURE notify_new_release();


--
-- Name: revision notify_new_revision; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_revision AFTER INSERT ON revision FOR EACH ROW EXECUTE PROCEDURE notify_new_revision();


--
-- Name: skipped_content notify_new_skipped_content; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notify_new_skipped_content AFTER INSERT ON skipped_content FOR EACH ROW EXECUTE PROCEDURE notify_new_skipped_content();


--
-- Name: entity_history update_entity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_entity AFTER INSERT OR UPDATE ON entity_history FOR EACH ROW EXECUTE PROCEDURE swh_update_entity_from_entity_history();


--
-- Name: cache_content_revision cache_content_revision_content_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_content_revision
    ADD CONSTRAINT cache_content_revision_content_fkey FOREIGN KEY (content) REFERENCES content(sha1_git);


--
-- Name: cache_content_revision_processed cache_content_revision_processed_revision_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_content_revision_processed
    ADD CONSTRAINT cache_content_revision_processed_revision_fkey FOREIGN KEY (revision) REFERENCES revision(id);


--
-- Name: cache_revision_origin cache_revision_origin_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_revision_origin
    ADD CONSTRAINT cache_revision_origin_origin_fkey FOREIGN KEY (origin, visit) REFERENCES origin_visit(origin, visit);


--
-- Name: cache_revision_origin cache_revision_origin_revision_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache_revision_origin
    ADD CONSTRAINT cache_revision_origin_revision_fkey FOREIGN KEY (revision) REFERENCES revision(id);


--
-- Name: content_ctags content_ctags_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_ctags
    ADD CONSTRAINT content_ctags_id_fkey FOREIGN KEY (id) REFERENCES content(sha1);


--
-- Name: content_fossology_license content_fossology_license_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_fossology_license
    ADD CONSTRAINT content_fossology_license_id_fkey FOREIGN KEY (id) REFERENCES content(sha1);


--
-- Name: content_fossology_license content_fossology_license_indexer_configuration_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_fossology_license
    ADD CONSTRAINT content_fossology_license_indexer_configuration_id_fkey FOREIGN KEY (indexer_configuration_id) REFERENCES indexer_configuration(id);


--
-- Name: content_fossology_license content_fossology_license_license_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_fossology_license
    ADD CONSTRAINT content_fossology_license_license_id_fkey FOREIGN KEY (license_id) REFERENCES fossology_license(id);


--
-- Name: content_language content_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_language
    ADD CONSTRAINT content_language_id_fkey FOREIGN KEY (id) REFERENCES content(sha1);


--
-- Name: content_mimetype content_mimetype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY content_mimetype
    ADD CONSTRAINT content_mimetype_id_fkey FOREIGN KEY (id) REFERENCES content(sha1);


--
-- Name: entity_equivalence entity_equivalence_entity1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_equivalence
    ADD CONSTRAINT entity_equivalence_entity1_fkey FOREIGN KEY (entity1) REFERENCES entity(uuid);


--
-- Name: entity_equivalence entity_equivalence_entity2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity_equivalence
    ADD CONSTRAINT entity_equivalence_entity2_fkey FOREIGN KEY (entity2) REFERENCES entity(uuid);


--
-- Name: entity entity_last_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_last_id_fkey FOREIGN KEY (last_id) REFERENCES entity_history(id);


--
-- Name: entity entity_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entity
    ADD CONSTRAINT entity_parent_fkey FOREIGN KEY (parent) REFERENCES entity(uuid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: fetch_history fetch_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY fetch_history
    ADD CONSTRAINT fetch_history_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: list_history list_history_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY list_history
    ADD CONSTRAINT list_history_entity_fkey FOREIGN KEY (entity) REFERENCES listable_entity(uuid);


--
-- Name: listable_entity listable_entity_uuid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY listable_entity
    ADD CONSTRAINT listable_entity_uuid_fkey FOREIGN KEY (uuid) REFERENCES entity(uuid);


--
-- Name: occurrence_history occurrence_history_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence_history
    ADD CONSTRAINT occurrence_history_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: occurrence occurrence_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY occurrence
    ADD CONSTRAINT occurrence_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: origin origin_lister_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin
    ADD CONSTRAINT origin_lister_fkey FOREIGN KEY (lister) REFERENCES listable_entity(uuid);


--
-- Name: origin origin_project_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin
    ADD CONSTRAINT origin_project_fkey FOREIGN KEY (project) REFERENCES entity(uuid);


--
-- Name: origin_visit origin_visit_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY origin_visit
    ADD CONSTRAINT origin_visit_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- Name: release release_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY release
    ADD CONSTRAINT release_author_fkey FOREIGN KEY (author) REFERENCES person(id);


--
-- Name: revision revision_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision
    ADD CONSTRAINT revision_author_fkey FOREIGN KEY (author) REFERENCES person(id);


--
-- Name: revision revision_committer_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision
    ADD CONSTRAINT revision_committer_fkey FOREIGN KEY (committer) REFERENCES person(id);


--
-- Name: revision_history revision_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY revision_history
    ADD CONSTRAINT revision_history_id_fkey FOREIGN KEY (id) REFERENCES revision(id);


--
-- Name: skipped_content skipped_content_origin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY skipped_content
    ADD CONSTRAINT skipped_content_origin_fkey FOREIGN KEY (origin) REFERENCES origin(id);


--
-- PostgreSQL database dump complete
--

