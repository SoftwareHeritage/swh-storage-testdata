--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.3
-- Dumped by pg_dump version 9.6.3

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


SET search_path = public, pg_catalog;

--
-- Name: task_run_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE task_run_status AS ENUM (
    'scheduled',
    'started',
    'eventful',
    'uneventful',
    'failed',
    'lost'
);


--
-- Name: TYPE task_run_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE task_run_status IS 'Status of a given task run';


--
-- Name: task_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE task_status AS ENUM (
    'next_run_not_scheduled',
    'next_run_scheduled',
    'disabled'
);


--
-- Name: TYPE task_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE task_status IS 'Status of a given task';


--
-- Name: swh_scheduler_compute_new_task_interval(text, interval, task_run_status); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_compute_new_task_interval(task_type text, current_interval interval, end_status task_run_status) RETURNS interval
    LANGUAGE plpgsql STABLE
    AS $$
declare
  task_type_row task_type%rowtype;
  adjustment_factor float;
begin
  select *
    from task_type
    where type = swh_scheduler_compute_new_task_interval.task_type
  into task_type_row;

  case end_status
  when 'eventful' then
    adjustment_factor := 1/task_type_row.backoff_factor;
  when 'uneventful' then
    adjustment_factor := task_type_row.backoff_factor;
  else
    -- failed or lost task: no backoff.
    adjustment_factor := 1;
  end case;

  return greatest(task_type_row.min_interval,
                  least(task_type_row.max_interval,
                        adjustment_factor * current_interval));
end;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE task (
    id bigint NOT NULL,
    type text NOT NULL,
    arguments jsonb NOT NULL,
    next_run timestamp with time zone NOT NULL,
    current_interval interval NOT NULL,
    status task_status NOT NULL
);


--
-- Name: TABLE task; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE task IS 'Schedule of recurring tasks';


--
-- Name: COLUMN task.arguments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.arguments IS 'Arguments passed to the underlying job scheduler. Contains two keys, ''args'' (list) and ''kwargs'' (object).';


--
-- Name: COLUMN task.next_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.next_run IS 'The next run of this task should be run on or after that time';


--
-- Name: COLUMN task.current_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task.current_interval IS 'The interval between two runs of this task, taking into account the backoff factor';


--
-- Name: swh_scheduler_create_tasks_from_temp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_create_tasks_from_temp() RETURNS SETOF task
    LANGUAGE plpgsql
    AS $$
begin
  return query
  insert into task (type, arguments, next_run, status, current_interval)
    select type, arguments, next_run, 'next_run_not_scheduled',
           (select default_interval from task_type tt where tt.type = tmp_task.type)
      from tmp_task
  returning task.*;
end;
$$;


--
-- Name: FUNCTION swh_scheduler_create_tasks_from_temp(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_scheduler_create_tasks_from_temp() IS 'Create tasks in bulk from the temporary table';


--
-- Name: task_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE task_run (
    id bigint NOT NULL,
    task bigint NOT NULL,
    backend_id text,
    scheduled timestamp with time zone,
    started timestamp with time zone,
    ended timestamp with time zone,
    metadata jsonb,
    status task_run_status DEFAULT 'scheduled'::task_run_status NOT NULL
);


--
-- Name: TABLE task_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE task_run IS 'History of task runs sent to the job-running backend';


--
-- Name: COLUMN task_run.backend_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_run.backend_id IS 'id of the task run in the job-running backend';


--
-- Name: COLUMN task_run.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_run.metadata IS 'Useful metadata for the given task run. For instance, the worker that took on the job, or the logs for the run.';


--
-- Name: swh_scheduler_end_task_run(text, task_run_status, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_end_task_run(backend_id text, status task_run_status, metadata jsonb DEFAULT '{}'::jsonb, ts timestamp with time zone DEFAULT now()) RETURNS task_run
    LANGUAGE sql
    AS $$
  update task_run
    set ended = ts,
        status = swh_scheduler_end_task_run.status,
        metadata = coalesce(task_run.metadata, '{}'::jsonb) || swh_scheduler_end_task_run.metadata
    where task_run.backend_id = swh_scheduler_end_task_run.backend_id
  returning *;
$$;


--
-- Name: swh_scheduler_grab_ready_tasks(text, timestamp with time zone, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_grab_ready_tasks(task_type text, ts timestamp with time zone DEFAULT now(), num_tasks bigint DEFAULT NULL::bigint) RETURNS SETOF task
    LANGUAGE sql
    AS $$
  update task
    set status='next_run_scheduled'
    from (
      select id from task
        where next_run <= ts
              and type = task_type
              and status='next_run_not_scheduled'
        order by next_run
        limit num_tasks
        for update skip locked
    ) next_tasks
    where task.id = next_tasks.id
  returning task.*;
$$;


--
-- Name: swh_scheduler_mktemp_task(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_mktemp_task() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_task (
    like task excluding indexes
  ) on commit drop;
  alter table tmp_task
    drop column id,
    drop column current_interval,
    drop column status;
$$;


--
-- Name: FUNCTION swh_scheduler_mktemp_task(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_scheduler_mktemp_task() IS 'Create a temporary table for bulk task creation';


--
-- Name: swh_scheduler_mktemp_task_run(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_mktemp_task_run() RETURNS void
    LANGUAGE sql
    AS $$
  create temporary table tmp_task_run (
    like task_run excluding indexes
  ) on commit drop;
  alter table tmp_task_run
    drop column id,
    drop column status;
$$;


--
-- Name: FUNCTION swh_scheduler_mktemp_task_run(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION swh_scheduler_mktemp_task_run() IS 'Create a temporary table for bulk task run scheduling';


--
-- Name: swh_scheduler_peek_ready_tasks(text, timestamp with time zone, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_peek_ready_tasks(task_type text, ts timestamp with time zone DEFAULT now(), num_tasks bigint DEFAULT NULL::bigint) RETURNS SETOF task
    LANGUAGE sql STABLE
    AS $$
select * from task
  where next_run <= ts
        and type = task_type
        and status = 'next_run_not_scheduled'
  order by next_run
  limit num_tasks;
$$;


--
-- Name: swh_scheduler_schedule_task_run(bigint, text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_schedule_task_run(task_id bigint, backend_id text, metadata jsonb DEFAULT '{}'::jsonb, ts timestamp with time zone DEFAULT now()) RETURNS task_run
    LANGUAGE sql
    AS $$
  insert into task_run (task, backend_id, metadata, scheduled, status)
    values (task_id, backend_id, metadata, ts, 'scheduled')
  returning *;
$$;


--
-- Name: swh_scheduler_schedule_task_run_from_temp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_schedule_task_run_from_temp() RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into task_run (task, backend_id, metadata, scheduled, status)
    select task, backend_id, metadata, scheduled, 'scheduled'
      from tmp_task_run;
  return;
end;
$$;


--
-- Name: swh_scheduler_start_task_run(text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_start_task_run(backend_id text, metadata jsonb DEFAULT '{}'::jsonb, ts timestamp with time zone DEFAULT now()) RETURNS task_run
    LANGUAGE sql
    AS $$
  update task_run
    set started = ts,
        status = 'started',
        metadata = coalesce(task_run.metadata, '{}'::jsonb) || swh_scheduler_start_task_run.metadata
    where task_run.backend_id = swh_scheduler_start_task_run.backend_id
  returning *;
$$;


--
-- Name: swh_scheduler_update_task_interval(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION swh_scheduler_update_task_interval() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  update task
    set status = 'next_run_not_scheduled',
        current_interval = swh_scheduler_compute_new_task_interval(type, current_interval, new.status),
        next_run = now () + swh_scheduler_compute_new_task_interval(type, current_interval, new.status)
    where id = new.task;
  return null;
end;
$$;


--
-- Name: dbversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE dbversion (
    version integer NOT NULL,
    release timestamp with time zone NOT NULL,
    description text NOT NULL
);


--
-- Name: TABLE dbversion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE dbversion IS 'Schema update tracking';


--
-- Name: task_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE task_id_seq OWNED BY task.id;


--
-- Name: task_run_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE task_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_run_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE task_run_id_seq OWNED BY task_run.id;


--
-- Name: task_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE task_type (
    type text NOT NULL,
    description text NOT NULL,
    backend_name text NOT NULL,
    default_interval interval NOT NULL,
    min_interval interval NOT NULL,
    max_interval interval NOT NULL,
    backoff_factor double precision NOT NULL,
    queue_max_length bigint
);


--
-- Name: TABLE task_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE task_type IS 'Types of schedulable tasks';


--
-- Name: COLUMN task_type.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.type IS 'Short identifier for the task type';


--
-- Name: COLUMN task_type.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.description IS 'Human-readable task description';


--
-- Name: COLUMN task_type.backend_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.backend_name IS 'Name of the task in the job-running backend';


--
-- Name: COLUMN task_type.default_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.default_interval IS 'Default interval for newly scheduled tasks';


--
-- Name: COLUMN task_type.min_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.min_interval IS 'Minimum interval between two runs of a task';


--
-- Name: COLUMN task_type.max_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.max_interval IS 'Maximum interval between two runs of a task';


--
-- Name: COLUMN task_type.backoff_factor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.backoff_factor IS 'Adjustment factor for the backoff between two task runs';


--
-- Name: COLUMN task_type.queue_max_length; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN task_type.queue_max_length IS 'Maximum length of the queue for this type of tasks';


--
-- Name: task id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY task ALTER COLUMN id SET DEFAULT nextval('task_id_seq'::regclass);


--
-- Name: task_run id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_run ALTER COLUMN id SET DEFAULT nextval('task_run_id_seq'::regclass);


--
-- Data for Name: dbversion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY dbversion (version, release, description) FROM stdin;
4	2017-07-17 19:01:45.437641+02	Work In Progress
\.


--
-- Data for Name: task; Type: TABLE DATA; Schema: public; Owner: -
--

COPY task (id, type, arguments, next_run, current_interval, status) FROM stdin;
\.


--
-- Name: task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('task_id_seq', 1, false);


--
-- Data for Name: task_run; Type: TABLE DATA; Schema: public; Owner: -
--

COPY task_run (id, task, backend_id, scheduled, started, ended, metadata, status) FROM stdin;
\.


--
-- Name: task_run_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('task_run_id_seq', 1, false);


--
-- Data for Name: task_type; Type: TABLE DATA; Schema: public; Owner: -
--

COPY task_type (type, description, backend_name, default_interval, min_interval, max_interval, backoff_factor, queue_max_length) FROM stdin;
\.


--
-- Name: dbversion dbversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dbversion
    ADD CONSTRAINT dbversion_pkey PRIMARY KEY (version);


--
-- Name: task task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task
    ADD CONSTRAINT task_pkey PRIMARY KEY (id);


--
-- Name: task_run task_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_run
    ADD CONSTRAINT task_run_pkey PRIMARY KEY (id);


--
-- Name: task_type task_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_type
    ADD CONSTRAINT task_type_pkey PRIMARY KEY (type);


--
-- Name: task_args; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_args ON task USING btree (((arguments -> 'args'::text)));


--
-- Name: task_kwargs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_kwargs ON task USING gin (((arguments -> 'kwargs'::text)));


--
-- Name: task_next_run_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_next_run_idx ON task USING btree (next_run);


--
-- Name: task_run_backend_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_run_backend_id_idx ON task_run USING btree (backend_id);


--
-- Name: task_run_task_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_run_task_idx ON task_run USING btree (task);


--
-- Name: task_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_type_idx ON task USING btree (type);


--
-- Name: task_run update_interval_on_task_end; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_interval_on_task_end AFTER UPDATE OF status ON task_run FOR EACH ROW WHEN ((new.status = ANY (ARRAY['eventful'::task_run_status, 'uneventful'::task_run_status, 'failed'::task_run_status, 'lost'::task_run_status]))) EXECUTE PROCEDURE swh_scheduler_update_task_interval();


--
-- Name: task_run task_run_task_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task_run
    ADD CONSTRAINT task_run_task_fkey FOREIGN KEY (task) REFERENCES task(id);


--
-- Name: task task_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY task
    ADD CONSTRAINT task_type_fkey FOREIGN KEY (type) REFERENCES task_type(type);


--
-- PostgreSQL database dump complete
--

