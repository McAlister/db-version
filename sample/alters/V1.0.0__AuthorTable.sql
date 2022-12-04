
-- This just checks if name exists, not that it is made of these columns.  
CREATE TABLE IF NOT EXISTS author (
	id serial primary_key,
	first_name varchar(32) not null,
	last_name varchar(32) not null,
	created_on date default current_date not null,
	Unique(first_name, last_name)
);

-- This just checks if name exists, not that it is made of these columns.  
Create index If Not Exists author_last_name_idx On author(last_name);


