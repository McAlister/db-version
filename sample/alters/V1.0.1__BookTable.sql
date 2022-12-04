
-- This just checks if name exists, not that it is made of these columns.  
CREATE TABLE IF NOT EXISTS book (
	id serial primary_key,
	title varchar(64) not null,
	author_id integer not null,
	created_on date default current_date not null,
	Unique(title, author_id)
);

-- This just checks if name exists, not that it is made of these columns.  
Create index If Not Exists book_title_idx On book(title);

-- There is no if not exists syntax for contraints so to make rerunnable drop and recreate.
ALTER TABLE book DROP CONSTRAINT IF EXISTS book_2_author_fk;
ALTER TABLE book ADD CONSTRAINT book_2_author_fk FOREIGN KEY (author_id) REFERENCES author (id);
