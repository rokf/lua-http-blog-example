create table users (
  id serial primary key not null,
  name text not null,
  email text unique not null,
  password text not null,
  created_at timestamp
);

create table posts (
  id serial primary key not null,
  title text not null,
  user_id integer not null,
  article text not null,
  created_at timestamp,
  updated_at timestamp
);
